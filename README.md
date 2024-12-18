# FundHive - Decentralized Milestone-Based Crowdfunding Platform

FundHive is a decentralized crowdfunding platform built on Stacks blockchain that enables projects to raise funds through milestone-based funding. The platform ensures accountability by only releasing funds when predefined project milestones are met and verified.

## Features

### Core Functionality
- **Milestone-Based Fund Distribution**: Funds are released only when project milestones are completed and verified
- **Transparent Progress Tracking**: All project progress is recorded on-chain
- **Automated Refund System**: Contributors can claim refunds if milestones are missed
- **Secure Fund Management**: Smart contract handles all fund movements

### Key Components
1. Project Management
   - Create projects with multiple milestones
   - Set funding targets and deadlines
   - Track project progress and completion

2. Milestone System
   - Define specific milestones with descriptions
   - Set milestone deadlines and funding amounts
   - Track milestone completion and fund release

3. Contribution Management
   - Accept STX contributions
   - Track contributor information
   - Handle refund distribution

4. Progress Tracking
   - Monitor funds released
   - Track contributor counts
   - Record milestone completion timestamps

## Smart Contract Overview

### Data Structures

#### Projects
```clarity
(define-map projects 
    { project-id: uint }
    {
        owner: principal,
        target-amount: uint,
        current-amount: uint,
        end-block: uint,
        milestone-count: uint,
        is-active: bool,
        last-milestone-deadline: uint,
        total-milestones-completed: uint
    }
)
```

#### Milestones
```clarity
(define-map milestones
    { project-id: uint, milestone-id: uint }
    {
        description: (string-ascii 256),
        amount: uint,
        completed: bool,
        released: bool,
        deadline: uint,
        completion-block: uint
    }
)
```

### Main Functions

#### Project Creation and Management
- `create-project`: Create a new crowdfunding project
- `add-milestone`: Add milestone details to a project
- `complete-milestone`: Mark a milestone as completed
- `release-milestone-funds`: Release funds for completed milestone

#### Contribution Handling
- `contribute`: Contribute STX to a project
- `claim-refund`: Claim refund for failed projects
- `get-refund-eligibility`: Check refund availability

#### Read-Only Functions
- `get-project`: Get project details
- `get-milestone`: Get milestone information
- `get-contribution`: Get contribution details
- `get-project-progress`: Get project progress metrics

## Setup and Deployment

### Prerequisites
- Clarinet
- Stacks CLI
- NodeJS and NPM

### Installation Steps
1. Clone the repository
```bash
git clone <repository-url>
cd fundhive
```

2. Install dependencies
```bash
npm install
```

3. Run tests
```bash
clarinet test
```

4. Deploy contract
```bash
clarinet deploy
```

## Usage Examples

### Creating a New Project
```clarity
(contract-call? .fundhive create-project 
    u1000000 ;; target amount
    u1000    ;; end block
    u3       ;; milestone count
    u900     ;; milestone deadline
)
```

### Adding a Milestone
```clarity
(contract-call? .fundhive add-milestone
    u1        ;; project-id
    u1        ;; milestone-id
    "Complete MVP"  ;; description
    u300000   ;; amount
    u500      ;; deadline
)
```

### Contributing to a Project
```clarity
(contract-call? .fundhive contribute u1)  ;; project-id
```

### Completing a Milestone
```clarity
(contract-call? .fundhive complete-milestone
    u1  ;; project-id
    u1  ;; milestone-id
)
```

## Security Considerations

1. Input Validation
   - All user inputs are validated
   - Project and milestone existence checks
   - Proper error handling

2. Access Control
   - Owner-only functions for sensitive operations
   - Contributor verification for refunds
   - Milestone completion verification

3. Fund Safety
   - Milestone-based fund release
   - Automated refund system
   - Protected fund transfers

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Unauthorized access attempt
- `ERR-NOT-FOUND (u102)`: Resource not found
- `ERR-INVALID-AMOUNT (u103)`: Invalid amount specified
- `ERR-MILESTONE-NOT-COMPLETED (u104)`: Milestone completion error
- `ERR-PROJECT-ENDED (u105)`: Project has ended
- `ERR-DEADLINE-PASSED (u106)`: Deadline has passed
- `ERR-NO-REFUND-AVAILABLE (u107)`: No refund available
- `ERR-INVALID-PROJECT (u108)`: Invalid project specified
- `ERR-INVALID-MILESTONE (u109)`: Invalid milestone specified
