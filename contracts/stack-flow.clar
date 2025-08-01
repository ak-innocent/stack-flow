;; Title: StackFlow Basic Income Protocol
;;
;; Summary: Revolutionary blockchain-based income redistribution system powered by Bitcoin's 
;;          unmatched security through Stacks Layer 2 infrastructure
;;
;; Description: StackFlow transforms economic inequality through automated, transparent, and 
;;             democratic income distribution. Built on Stacks' Bitcoin-secured foundation, 
;;             this protocol enables verified community members to receive periodic STX 
;;             payments from a collectively managed treasury. The system incorporates 
;;             sophisticated governance mechanisms allowing participants to vote on critical 
;;             parameters, emergency safeguards for crisis management, and comprehensive 
;;             transparency tracking. StackFlow represents the future of decentralized 
;;             economic empowerment, combining Bitcoin's security with programmable smart 
;;             contract flexibility to create sustainable financial inclusion for all.
;;

;; CONSTANTS & ERROR DEFINITIONS

(define-constant CONTRACT-OWNER tx-sender)
(define-constant DISTRIBUTION-INTERVAL u144) ;; ~1 day in blocks
(define-constant MINIMUM-BALANCE u10000000) ;; Minimum treasury balance (10 STX)
(define-constant MAX-PROPOSED-VALUE u1000000000000) ;; Maximum governance proposal value
(define-constant PROPOSAL-VOTING-PERIOD u1440) ;; ~10 days in blocks

;; Comprehensive error handling system
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-REGISTERED (err u102))
(define-constant ERR-INELIGIBLE (err u103))
(define-constant ERR-COOLDOWN-ACTIVE (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-UNAUTHORIZED (err u107))
(define-constant ERR-INVALID-PROPOSAL (err u108))
(define-constant ERR-EXPIRED-PROPOSAL (err u109))
(define-constant ERR-INVALID-VALUE (err u110))
(define-constant ERR-ALREADY-VOTED (err u111))
(define-constant ERR-CONTRACT-PAUSED (err u112))

;; STATE VARIABLES

(define-data-var treasury-balance uint u0)
(define-data-var total-participants uint u0)
(define-data-var distribution-amount uint u1000000) ;; 1 STX = 1,000,000 microSTX
(define-data-var last-distribution-height uint u0)
(define-data-var paused bool false)
(define-data-var proposal-counter uint u0)

;; DATA STRUCTURES

;; Comprehensive participant registry with activity tracking
(define-map participants
  principal
  {
    registered: bool,
    last-claim-height: uint,
    total-claimed: uint,
    verification-status: bool,
    join-height: uint,
    claims-count: uint,
  }
)

;; Democratic governance proposal management
(define-map governance-proposals
  uint
  {
    proposer: principal,
    proposal-type: (string-ascii 32),
    proposed-value: uint,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 10),
    expiry-height: uint,
  }
)

;; Anti-fraud voting verification system
(define-map voter-records
  {
    proposal-id: uint,
    voter: principal,
  }
  bool
)

;; INTERNAL UTILITY FUNCTIONS

;; Verify contract owner permissions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Comprehensive eligibility verification for income distribution
(define-private (is-eligible (user principal))
  (match (map-get? participants user)
    participant-info (and
      (get verification-status participant-info)
      (>= (- stacks-block-height (get last-claim-height participant-info))
        DISTRIBUTION-INTERVAL
      )
      (>= (var-get treasury-balance) (var-get distribution-amount))
      (not (var-get paused))
    )
    false
  )
)

;; Update participant statistics after successful distribution
(define-private (update-participant-record
    (user principal)
    (claimed-amount uint)
  )
  (match (map-get? participants user)
    current-info (ok (map-set participants user
      (merge current-info {
        last-claim-height: stacks-block-height,
        total-claimed: (+ (get total-claimed current-info) claimed-amount),
        claims-count: (+ (get claims-count current-info) u1),
      })
    ))
    ERR-NOT-REGISTERED
  )
)

;; Governance proposal type validation
(define-private (is-valid-proposal-type (proposal-type (string-ascii 32)))
  (or
    (is-eq proposal-type "distribution-amount")
    (is-eq proposal-type "distribution-interval")
    (is-eq proposal-type "minimum-balance")
  )
)

;; Proposal value bounds checking
(define-private (is-valid-proposed-value (value uint))
  (and
    (> value u0)
    (<= value MAX-PROPOSED-VALUE)
  )
)

;; CORE PUBLIC FUNCTIONS

;; Community registration for StackFlow participation
(define-public (register)
  (let ((existing-record (map-get? participants tx-sender)))
    (asserts! (is-none existing-record) ERR-ALREADY-REGISTERED)
    (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
    (map-set participants tx-sender {
      registered: true,
      last-claim-height: u0,
      total-claimed: u0,
      verification-status: false,
      join-height: stacks-block-height,
      claims-count: u0,
    })
    (var-set total-participants (+ (var-get total-participants) u1))
    (ok true)
  )
)

;; Administrative verification of community members
(define-public (verify-participant (user principal))
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (asserts! (is-some (map-get? participants user)) ERR-NOT-REGISTERED)
    (map-set participants user
      (merge (unwrap! (map-get? participants user) ERR-NOT-REGISTERED) { verification-status: true })
    )
    (ok true)
  )
)

;; Execute periodic income distribution claim
(define-public (claim-ubi)
  (let (
      (user tx-sender)
      (distribution-amt (var-get distribution-amount))
    )
    (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-eligible user) ERR-INELIGIBLE)
    (asserts! (>= (var-get treasury-balance) distribution-amt)
      ERR-INSUFFICIENT-FUNDS
    )
    ;; Execute STX transfer to qualified participant
    (try! (as-contract (stx-transfer? distribution-amt tx-sender user)))
    ;; Update treasury balance and participant records
    (var-set treasury-balance (- (var-get treasury-balance) distribution-amt))
    (try! (update-participant-record user distribution-amt))
    (ok distribution-amt)
  )
)

;; Community treasury funding mechanism
(define-public (contribute (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (ok amount)
  )
)

;; DEMOCRATIC GOVERNANCE SYSTEM

;; Submit community governance proposal
(define-public (submit-proposal
    (proposal-type (string-ascii 32))
    (proposed-value uint)
  )
  (let ((new-proposal-id (+ (var-get proposal-counter) u1)))
    (asserts! (is-some (map-get? participants tx-sender)) ERR-NOT-REGISTERED)
    (asserts! (is-valid-proposal-type proposal-type) ERR-INVALID-PROPOSAL)
    (asserts! (is-valid-proposed-value proposed-value) ERR-INVALID-VALUE)
    (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
    (map-set governance-proposals new-proposal-id {
      proposer: tx-sender,
      proposal-type: proposal-type,
      proposed-value: proposed-value,
      votes-for: u0,
      votes-against: u0,
      status: "active",
      expiry-height: (+ stacks-block-height PROPOSAL-VOTING-PERIOD),
    })
    (var-set proposal-counter new-proposal-id)
    (ok new-proposal-id)
  )
)

;; Participate in democratic voting process
(define-public (vote
    (proposal-id uint)
    (vote-for bool)
  )
  (let (
      (proposal (unwrap! (map-get? governance-proposals proposal-id) ERR-INVALID-PROPOSAL))
      (voter-key {
        proposal-id: proposal-id,
        voter: tx-sender,
      })
    )
    (asserts! (is-some (map-get? participants tx-sender)) ERR-NOT-REGISTERED)
    (asserts! (is-none (map-get? voter-records voter-key)) ERR-ALREADY-VOTED)
    (asserts! (<= proposal-id (var-get proposal-counter)) ERR-INVALID-PROPOSAL)
    (asserts! (< stacks-block-height (get expiry-height proposal))
      ERR-EXPIRED-PROPOSAL
    )
    (asserts! (is-eq (get status proposal) "active") ERR-INVALID-PROPOSAL)
    ;; Record vote and update proposal tallies
    (map-set voter-records voter-key true)
    (map-set governance-proposals proposal-id
      (merge proposal {
        votes-for: (if vote-for
          (+ (get votes-for proposal) u1)
          (get votes-for proposal)
        ),
        votes-against: (if vote-for
          (get votes-against proposal)
          (+ (get votes-against proposal) u1)
        ),
      })
    )
    (ok true)
  )
)

;; EMERGENCY CONTROL FUNCTIONS

;; Activate emergency protocol suspension
(define-public (pause)
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (var-set paused true)
    (ok true)
  )
)

;; Resume normal protocol operations
(define-public (unpause)
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (var-set paused false)
    (ok true)
  )
)