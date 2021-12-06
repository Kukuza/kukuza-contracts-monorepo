// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract WakalaEscrow  {
    
    /**
     * Encription keys used to enxcrypt phone numbers.
     **/
    string private encryptionKey;
    
    uint private nextTransactionID = 0; 

    uint private agentFee  = 2500000000000000;
    
    uint private wakalaFee = 0;

    event AgentPairingEvent(WakalaTransaction wtx);

    event TransactionInitEvent(WakalaTransaction wtx);
    
    event ClientConfirmationEvent(WakalaTransaction wtx);
    
    event AgentConfirmationEvent(WakalaTransaction wtx);
    
    event ConfirmationCompletedEvent(WakalaTransaction wtx);
    
    event TransactionCompletionEvent(WakalaTransaction wtx);
    
     /**
      * Address of the cUSD token on Alfajores: 
      */
    address internal cUsdTokenAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;
    
      // Maps unique payment IDs to escrowed payments.
      // These payment IDs are the temporary wallet addresses created with the escrowed payments.
    mapping(uint => WakalaTransaction) public escrowedPayments;
    
    /**
     * An enum of the transaction types. either deposit or withdrawal.
     */
    enum TransactionType { DEPOSIT, WITHDRAWAL }
    
    /**
     * An enum of all the states of a transaction.
     * AWAITING_AGENT :- transaction initialized and waitning for agent pairing.
     * AWAITING_CONFIRMATIONS :- agent paired awaiting for approval by the agent and client.
     * CONFIRMED :- transactions confirmed by both client and aagent.
     * DONE :- transaction completed, currency moved from escrow to destination addess.
     */
    enum Status { AWAITING_AGENT, AWAITING_CONFIRMATIONS, CONFIRMED, CANCELED, DONE }
     
    /**
     * Object of escrow transactions.
     **/
    struct  WakalaTransaction {
        uint id;
        TransactionType txType;
        address clientAddress;
        address agentAddress;
        Status status;
        // bytes32 clientPhoneNo;
        // bytes32 agentPhoneNo;
        uint256 amount;
        uint256 agentFee;
        uint256 wakalaFee;
        uint256 grossAmount;
        bool agentApproval;
        bool clientApproval;
    }
   
  
//   constructor(string memory _encryptionKey) public {
//       encryptionKey = _encryptionKey;
//   }
   
   /**
    * Client initialize withdrawal transaction.
    *
    **/
   function initializeWithdrawalTransaction(uint256 _amount) public returns(uint) {
        require(_amount > 0, "Amount to deposit must be greater than 0.");
        
        uint wtxID = nextTransactionID;
        nextTransactionID++;
        
        uint grossAmount = wakalaFee + agentFee + _amount;
        WakalaTransaction storage newPayment = escrowedPayments[wtxID];
        
        newPayment.clientAddress = msg.sender;
        newPayment.id = wtxID;
        newPayment.txType = TransactionType.WITHDRAWAL;
        newPayment.amount = _amount;
        newPayment.agentFee = agentFee;
        newPayment.wakalaFee = wakalaFee;
        newPayment.grossAmount = grossAmount;
        newPayment.status = Status.AWAITING_AGENT;
        
        // newPayment.clientPhoneNo = keccak256(abi.encodePacked(_phoneNumber, encryptionKey));
        newPayment.agentApproval = false;
        newPayment.clientApproval = false;
        
        require(
            ERC20(cUsdTokenAddress).transferFrom(
            msg.sender,
            address(this), 
            grossAmount),
            "You don't have enough cUSD to make this request."
        );
    
        emit TransactionInitEvent(newPayment);
    
        return wtxID;
   }
   
   /**
    * Client initialize deposit transaction.
    * 
    **/
   function initializeDepositTransaction(uint256 _amount) public returns(uint) {
        require(_amount > 0, "Amount to deposit must be greater than 0.");
        
        uint wtxID = nextTransactionID;
        nextTransactionID++;
        
        WakalaTransaction storage newPayment = escrowedPayments[wtxID];
        
        uint netFee = wakalaFee + agentFee;
        uint grossAmount = netFee + _amount;
        
        newPayment.clientAddress = msg.sender;
        newPayment.id = wtxID;
        newPayment.txType = TransactionType.DEPOSIT;
        newPayment.amount = _amount;
        newPayment.agentFee = agentFee;
        newPayment.wakalaFee = wakalaFee;
        newPayment.grossAmount = grossAmount;
        newPayment.status = Status.AWAITING_AGENT;
        
        // newPayment.clientPhoneNo = keccak256(abi.encodePacked(_phoneNumber, encryptionKey));
        newPayment.agentApproval = false;
        newPayment.clientApproval = false;
        
        emit TransactionInitEvent(newPayment);
        
        return wtxID;
   }
    
    /**
     * Marks pairs the client to an agent to attent to the transaction. 
     * @param _transactionid the identifire of the transaction.
     */
    function agentAcceptWithdrawalTransaction(uint _transactionid) public 
     awaitAgent(_transactionid) withdrawalsOnly(_transactionid)  {
         
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        
        require(wtx.clientAddress != msg.sender);
        
        wtx.agentAddress = msg.sender;
        wtx.status = Status.AWAITING_CONFIRMATIONS;
        
        emit AgentPairingEvent(wtx);
    }
    
    /**
     * Marks pairs the client to an agent to attent to the transaction. 
     * @param _transactionid the identifire of the transaction.
     */
    function agentAcceptDepositTransaction(uint _transactionid) public
        awaitAgent(_transactionid) depositsOnly(_transactionid)
        balanceGreaterThanAmount(_transactionid)
        payable {
        
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        
        require(wtx.clientAddress != msg.sender);

        wtx.agentAddress = msg.sender;
        wtx.status = Status.AWAITING_CONFIRMATIONS;
        
        require(
          ERC20(cUsdTokenAddress).transferFrom(
            msg.sender,
            address(this), 
            wtx.grossAmount
          ),
          "You don't have enough cUSD to accept this request."
        );
        
        emit AgentPairingEvent(wtx);
    }
    
    
    /**
     * Client confirms that s/he has sent money to the agent.
     */
    function clientConfirmPayment(uint _transactionid) public
     awaitConfirmation(_transactionid)
     clientOnly(_transactionid) {
        
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        
        require(!wtx.clientApproval, "Client already confirmed payment!!");
        wtx.clientApproval = true;
        
        emit ClientConfirmationEvent(wtx);
        
        if (wtx.agentApproval) {
            wtx.status = Status.CONFIRMED;
            emit ConfirmationCompletedEvent(wtx);
            finalizeTransaction(_transactionid);
        }
    }

    /**
     * Agent comnfirms that the payment  has been made.
     */
    function agentConfirmPayment(uint _transactionid) public 
    awaitConfirmation(_transactionid)
    agentOnly(_transactionid) {
        
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        
        require(!wtx.agentApproval, "Agent already confirmed payment!!");
        wtx.agentApproval = true;
        
        emit AgentConfirmationEvent(wtx);
        
        if (wtx.clientApproval) {
            wtx.status = Status.CONFIRMED;
            emit ConfirmationCompletedEvent(wtx);
            finalizeTransaction(_transactionid);
        }
    }
    
    /**
     * Can be automated in the frontend by use of event listeners. eg on confirmation event.
     **/ 
    function finalizeTransaction(uint _transactionid) private {
        
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        
        require(wtx.clientAddress == msg.sender || wtx.agentAddress == msg.sender,
            "Only the involved parties can finalize the transaction.!!");
       
        require(wtx.status == Status.CONFIRMED, "Contract not yet confirmed by both parties!!");
        
        wtx.status = Status.DONE;
        
        if (wtx.txType == TransactionType.DEPOSIT) {
            require(ERC20(cUsdTokenAddress).transfer(wtx.clientAddress, wtx.amount),
              "Transaction failed.");
              
            require(ERC20(cUsdTokenAddress).transfer(wtx.agentAddress, wtx.agentFee),
              "Transaction failed.");
        } else {
            
            require(ERC20(cUsdTokenAddress).transfer(wtx.agentAddress, wtx.amount + wtx.agentFee),
              "Transaction failed.");
        }
        
        emit TransactionCompletionEvent(wtx);
    }
    
    
    /**
     * Prevents users othe than the agent from running the logic.
     * @param _transactionid the transaction being processed.
     */
    modifier agentOnly(uint _transactionid) {
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        require(msg.sender == wtx.agentAddress, "Method can only be called by the agent");
        _;
    }
    
    /**
     * Run the method for deposit transactions only.
     */
    modifier depositsOnly(uint _transactionid) {
         WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        require(wtx.txType == TransactionType.DEPOSIT, 
            "Method can only be called for deposit transactions only!!");
        _;
    }
    
    /**
     * Run the method for withdrawal transactions only.
     * @param _transactionid the transaction being processed.
     */
    modifier withdrawalsOnly(uint _transactionid) {
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        require(wtx.txType == TransactionType.WITHDRAWAL,
        "Method can only be called for withdrawal transactions only!!");
        _;
    }
    
    /**
     * Prevents users othe than the client from running the logic.
     * @param _transactionid the transaction being processed.
     */
    modifier clientOnly(uint _transactionid) {
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        require(msg.sender == wtx.clientAddress, "Method can only be called by the client!!");
        _;
    }
    
    /**
     * Prevents users othe than the client from running the logic.
     * @param _transactionid the transaction being processed.
     */
    modifier awaitConfirmation(uint _transactionid) {
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        require(wtx.status == Status.AWAITING_CONFIRMATIONS);
        _;
    }
    
    /**
     * Prevents prevents double pairing of agents to transactions.
     * @param _transactionid the transaction being processed.
     */
    modifier awaitAgent(uint _transactionid) {
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        require(wtx.status == Status.AWAITING_AGENT);
        _;
    }
    
    /**
     * Prevents users othe than the client from running the logic
     * @param _transactionid the transaction being processed.
     */
    modifier balanceGreaterThanAmount(uint _transactionid) {
        WakalaTransaction storage wtx = escrowedPayments[_transactionid];
        require(ERC20(cUsdTokenAddress).balanceOf(address(msg.sender)) > wtx.grossAmount,
            "Your balance must be greater than the transaction gross amount.");
        _;
    }
  
}