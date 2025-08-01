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