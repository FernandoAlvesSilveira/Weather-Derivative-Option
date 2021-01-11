//pragma solidity ^0.6.0;
pragma solidity >=0.4.22 <0.8.0;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";

contract WeatherDerivative is ChainlinkClient {
    
     struct option {
        uint maturity;
        uint strike;
        uint payoff;
        uint id;
    }
    
    struct client {
        address name;
        uint id;
        uint maturity;
        uint strike;
        uint payoff;
    }
    

    //address self = address(this);
    //uint256 public balance = self.balance;
    
    //mapping (address => uint) private balance;
    address public owner;
    event LogRealizeDeposit(address numeroDaConta, uint quantidade);
    
    modifier ownerOnly {
        require(msg.sender == owner);
        _;
    }


    
    option[] public options;
    uint public nextId = 1;
    mapping (address => uint) private contractBalance;
    //mapping (address => uint) private clients;
    client[] public clients;
    
    function createOption(uint vencimento, uint strike,uint payoff) public payable {
        require(msg.sender == owner && msg.value == payoff);
        options.push(option(vencimento, strike, payoff, nextId));
        nextId++;
    }
    
    function listOption(uint id) view public returns(uint, uint, uint, uint) {
        uint i = _find(id);
        return( options[i].id,
                options[i].maturity,
                options[i].strike,
                options[i].payoff);
    }
    
    function listClients(uint id) view public returns (address, uint, uint, uint, uint) {
        uint i = _findClient(id);
        return (clients[i].name,
                clients[i].id,
                clients[i].strike,
                clients[i].payoff,
                clients[i].maturity);
    }
    

    function listMargin() private view returns (uint) {
        return address(this).balance;
    }
    

    function _find(uint id) view internal returns(uint) {
        for(uint i = 0; i < options.length; i++) {
          if(options[i].id == id) {
            return i;
          }
        }
        revert('Apolice não encontrada');
    }
    
    function _findClient(uint id) view internal returns(uint) {
        for(uint i = 0; i < clients.length; i++) {
          if(clients[i].id == id) {
            return i;
          }
        }
        revert('Cliente não encontrado');
    }
    
    function buyOption(uint id, uint maturity, uint strike, uint payoff) public payable returns (bool){
        //require(msg.sender != dono);
        //uint i = _find(id);
        //address nome = msg.sender;
        //uint _id = i;
        uint _payoff = options[id].payoff;
        require(msg.value == _payoff);
        //contractBalance[msg.sender] += msg.value;
        clients.push(client(msg.sender, id, maturity, strike, payoff));
        exclude(id);
    }
    
    
    
    function exercise(uint id) public {
        uint i = _findClient(id);
        uint _payoff = clients[i].payoff;
        uint _strike = clients[i].strike;
        uint DD = degreeDay;
        address rec = clients[i].name;
        address payable receiver = address(uint160(rec));
        //aqui implementar a função do oraculo
        if (DD > _strike) {
            receiver.transfer(_payoff);
            excludeClient(id);
            
        } 
        //revert('Condições não atendidas');
        
    }
    
    //função provisoria de retirada de lucro
    function withdraw() public {
        require(msg.sender == owner);
        msg.sender.transfer(address(this).balance);
    }
    

    
    //função testada
    function exclude(uint id) private {
        //require(msg.sender == dono);
        uint i = _find(id);
        delete options[i];
    }
    
    //testar funcionamento 
    function excludeClient(uint id) private {
        //require(msg.sender == dono);
        uint i = _findClient(id);
        delete clients[i];
    }
    
    uint256 public degreeDay;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    /**
     * Network: Kovan
     * Oracle: Chainlink - 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
     * Job ID: Chainlink - 29fa9aa13bf1468788b7cc4a500a45b8
     * Fee: 0.1 LINK
     */
    constructor() public {
        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        owner = msg.sender;
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target price
     * data, then multiply by 100 (to remove decimal places from price).
     */
    function requestCulmulativeDegreeDay() public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        //request.add("get", "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD");
        request.add("get", "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/weatherdata/degreedays?&unitGroup=us&degreeDayStats=true&degreeDayStartDate=2020-6-1&degreeDayEndDate=2020-6-5&degreeDayTempBase=65&degreeDayInverse=false&degreeDayFocusYear=2020&shortColumnNames=true&contentType=json&location=Herndon,VA&key=4MB76PFUBH2CC5M32ZC2K83W3");
        // Set the path to find the desired data in the API response, where the response format is:
        // {"USD":243.33}
        //request.add("path", "columns.mint.type");
        request.add("path", "locations.Herndon,VA.values.1.cumulativedegreedays");
        // Multiply the result by 100 to remove decimals
        request.addInt("times", 100);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId)
    {
        degreeDay = _price;
    }
}

