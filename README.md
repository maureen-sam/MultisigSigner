# MultisigSigner

MultisigSigner is an address reputation system smart contract for multisig wallet signer reliability and responsiveness scoring on the Stacks blockchain. This contract tracks and evaluates the performance of multisig signers based on their responsiveness and reliability in signing transactions.

## Features

- **Signer Reputation Tracking**: Monitor and score individual signer performance
- **Multisig Wallet Management**: Register and manage multisig wallets with authorized signers
- **Responsiveness Scoring**: Track response times and calculate responsiveness scores
- **Reliability Scoring**: Monitor successful vs failed signatures
- **Weighted Reputation System**: Combine responsiveness (60%) and reliability (40%) for overall reputation
- **Historical Event Tracking**: Store detailed signature event history
- **Admin Controls**: Manual score adjustments and wallet management
- **Query Interface**: Read-only functions for retrieving scores and statistics

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Contract Version**: 1.0.0
- **Clarity Version**: 2
- **Epoch**: 2.5
- **Maximum Score**: 100 (percentage-based)
- **Maximum Signers per Multisig**: 20

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- Node.js (for additional tooling)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd MultisigSigner
```

2. Navigate to the contract directory:
```bash
cd MultisigSigner_contract
```

3. Install dependencies:
```bash
npm install
```

4. Run tests:
```bash
clarinet test
```

## Usage Examples

### Register a Multisig Wallet

```clarity
;; Register a new multisig wallet with 3 signers requiring 2 signatures
(contract-call? .MultisigSigner register-multisig
  (list 'SP1SIGNER1 'SP2SIGNER2 'SP3SIGNER3)
  u2)
```

### Record a Signature Event

```clarity
;; Record a successful signature with 5-block response time
(contract-call? .MultisigSigner record-signature
  'SP1SIGNER1
  u1
  'SP1MULTISIG
  true
  u5)
```

### Check Signer Reputation

```clarity
;; Get overall reputation score for a signer
(contract-call? .MultisigSigner get-overall-reputation 'SP1SIGNER1)

;; Check if signer meets minimum reliability threshold
(contract-call? .MultisigSigner is-reliable-signer 'SP1SIGNER1 u75)
```

## Contract Functions Documentation

### Public Functions

#### `register-multisig`
Registers a new multisig wallet with authorized signers.
- **Parameters**:
  - `signers`: List of up to 20 principal addresses
  - `required-sigs`: Number of required signatures
- **Access**: Contract owner only
- **Returns**: `(response bool uint)`

#### `record-signature`
Records a signature event for performance tracking.
- **Parameters**:
  - `signer`: Principal address of the signer
  - `tx-id`: Transaction identifier
  - `multisig-wallet`: Multisig wallet principal
  - `signed`: Whether the signer successfully signed
  - `response-time`: Response time in blocks
- **Access**: Authorized multisig wallet or contract owner
- **Returns**: `(response bool uint)`

#### `record-transaction-completion`
Updates multisig wallet transaction statistics.
- **Parameters**:
  - `multisig-wallet`: Multisig wallet principal
  - `successful`: Whether the transaction was successful
- **Access**: Authorized multisig wallet or contract owner
- **Returns**: `(response bool uint)`

#### `adjust-signer-score`
Manually adjusts signer scores (admin function).
- **Parameters**:
  - `signer`: Principal address of the signer
  - `responsiveness`: New responsiveness score (0-100)
  - `reliability`: New reliability score (0-100)
- **Access**: Contract owner only
- **Returns**: `(response bool uint)`

### Read-Only Functions

#### `get-signer-score`
Retrieves complete signer score data.
- **Parameters**: `signer` (principal)
- **Returns**: Optional signer score record

#### `get-multisig-info`
Gets multisig wallet configuration and statistics.
- **Parameters**: `wallet` (principal)
- **Returns**: Optional multisig wallet record

#### `get-signature-event`
Retrieves specific signature event details.
- **Parameters**: `signer` (principal), `tx-id` (uint)
- **Returns**: Optional signature event record

#### `get-overall-reputation`
Calculates weighted overall reputation score.
- **Parameters**: `signer` (principal)
- **Returns**: `(response uint uint)` - Weighted score (60% responsiveness, 40% reliability)

#### `is-reliable-signer`
Checks if signer meets minimum reputation threshold.
- **Parameters**: `signer` (principal), `min-score` (uint)
- **Returns**: `(response bool uint)`

## Data Structures

### Signer Scores
```clarity
{
  responsiveness-score: uint,     ;; 0-100 based on response time
  reliability-score: uint,        ;; 0-100 based on success rate
  total-requests: uint,           ;; Total signature requests
  successful-signatures: uint,    ;; Number of successful signatures
  failed-signatures: uint,        ;; Number of failed signatures
  average-response-time: uint,    ;; Average response time in blocks
  last-activity: uint            ;; Block height of last activity
}
```

### Multisig Wallets
```clarity
{
  signers: (list 20 principal),     ;; List of authorized signers
  required-signatures: uint,        ;; Required signatures for transactions
  total-transactions: uint,         ;; Total transaction count
  successful-transactions: uint     ;; Successful transaction count
}
```

## Scoring Algorithm

### Responsiveness Score
- **Excellent (100)**: Response within 6 blocks (~1 hour)
- **Good (20-100)**: Response within 144 blocks (~24 hours), linearly decreasing
- **Poor (20)**: Response over 144 blocks

### Reliability Score
- Calculated as: `(successful_signatures / total_requests) * 100`
- New signers start with a default score of 50

### Overall Reputation
- Weighted average: `(responsiveness * 0.6) + (reliability * 0.4)`

## Deployment Guide

### Local Development
```bash
# Start local devnet
clarinet integrate

# Deploy contract
clarinet deploy --devnet
```

### Testnet Deployment
```bash
# Configure testnet settings in settings/Testnet.toml
clarinet deploy --testnet
```

### Mainnet Deployment
```bash
# Configure mainnet settings in settings/Mainnet.toml
clarinet deploy --mainnet
```

## Security Notes

### Access Controls
- Only contract owner can register multisig wallets
- Only contract owner can manually adjust scores
- Only authorized multisig wallets can record signature events
- All score modifications are logged on-chain

### Data Integrity
- Scores are capped at maximum values to prevent overflow
- Default scores provide fair starting points for new signers
- Historical events are immutable once recorded

### Best Practices
- Regularly monitor signer performance metrics
- Set appropriate minimum reputation thresholds
- Use time-based analysis for trend identification
- Implement off-chain monitoring for real-time alerts

## Error Codes

- `u100`: `ERR_NOT_AUTHORIZED` - Caller not authorized for operation
- `u101`: `ERR_SIGNER_NOT_FOUND` - Signer not found in records
- `u102`: `ERR_INVALID_SCORE` - Score value exceeds maximum allowed
- `u103`: `ERR_MULTISIG_NOT_FOUND` - Multisig wallet not registered
- `u104`: Empty signers list provided
- `u105`: Required signatures exceed signer count

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is open source. Please refer to the LICENSE file for details.