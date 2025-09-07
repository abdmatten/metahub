# Meta Hub Smart Contract

A comprehensive multi-layer smart contract for the Stacks blockchain that combines identity management, subscriptions, bridging, prediction markets, and DAO governance.

## Features

### Identity Management
- Decentralized Identity (DID) system
- Reputation tracking
- Identity verification system

### Subscription System
- Three-tiered membership (Bronze, Silver, Gold)
- Time-based subscriptions
- Automated payment processing

### Cross-Chain Bridge
- Asset locking mechanism
- Secure claim process
- Cross-chain asset tracking

### Prediction Markets
- Binary outcome markets
- Betting functionality
- Market resolution system
- Pool-based pricing

### DAO Governance
- Proposal creation and management
- Voting system
- Proposal execution mechanism

### Treasury Management
- STX token handling
- Yield distribution
- Balance tracking

## Usage

### Identity Functions
```clarity
(register-identity principal) ;; Register new identity
(verify-identity principal) ;; Verify an identity
(add-reputation principal uint) ;; Add reputation points
```

### Subscription Functions
```clarity
(subscribe uint uint) ;; Subscribe to a tier for duration
```

### Bridge Functions
```clarity
(lock-asset uint string-ascii uint) ;; Lock assets for bridging
(claim-asset uint) ;; Claim bridged assets
```

### Market Functions
```clarity
(create-market string-ascii) ;; Create new prediction market
(bet uint bool uint) ;; Place a bet
(resolve-market uint bool) ;; Resolve market outcome
```

### DAO Functions
```clarity
(create-proposal string-ascii) ;; Create new proposal
(vote uint bool) ;; Vote on proposal
(execute-proposal uint) ;; Execute passed proposal
```

### Treasury Functions
```clarity
(fund-treasury uint) ;; Add funds to treasury
(distribute-yield principal uint) ;; Distribute yield to recipient
```

## Error Handling

The contract includes comprehensive error handling with standard error codes:
- ERR-INVALID-USER (u100)
- ERR-UNAUTHORIZED (u101)
- ERR-INVALID-AMOUNT (u102)
- ERR-INVALID-ID (u103)

## Security Features

- Authentication checks
- Authorization validation
- Safe STX transfer operations
- Type-safe data structures
- Input validation

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
