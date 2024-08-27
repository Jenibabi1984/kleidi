# Test List

- cross chain deployment of the wallet deployer system, check that all addresses are the same on each chain
- cross chain deployment, same contract addresses, different whitelisted calldata and addresses

## Scenario Test

- [ ] full Morpho Blue whitelisted calldata walkthrough
    - [x] supply collateral
    - [x] withdraw collateral
    - [ ] borrow
    - [ ] repay
    - [ ] supply borrow asset
    - [ ] withdraw borrow asset
- [x] deploy safe with timelock, guard, and recovery spell, safe owners enact malicious proposal, guardian pauses, recovery spell rotates signers, new transactions are sent
- [ ] hot signers move funds from one DeFi protocol to another
- [ ] hot signers get revoked by the Safe
- [ ] privilege escalation impossible by hot signers
- [ ] mutative functions cannot be called while paused

# Formal Verification

- [x] impossible to have self calls whitelisted
- [x] pausing cancels all in flight proposals
- [x] not possible to have more than one admin
- [x] not possible to create new roles => implies no other roles outside of admin and hot signers can have any addresses in their list
- [x] timelock duration is always less than or equal to the maximum timelock duration, and always greater than or equal to the minimum timelock duration

## Proposal Invariants

- !isOperationExpired(id) => **timestamps[id]** > 1 => **_liveProposals** does contain id
- **timestamps[id]** == 1 => **_liveProposals** does not contain id