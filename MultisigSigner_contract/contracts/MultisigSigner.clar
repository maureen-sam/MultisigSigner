
;; title: MultisigSigner
;; version: 1.0.0
;; summary: Address reputation system for multisig wallet signer reliability and responsiveness scoring
;; description: This contract tracks and scores multisig signers based on their responsiveness and reliability

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_SIGNER_NOT_FOUND (err u101))
(define-constant ERR_INVALID_SCORE (err u102))
(define-constant ERR_MULTISIG_NOT_FOUND (err u103))

;; Maximum score value (100 for percentage)
(define-constant MAX_SCORE u100)

;; data vars
;;
(define-data-var contract-owner principal CONTRACT_OWNER)

;; data maps
;;
;; Track signer reputation scores
(define-map signer-scores principal {
    responsiveness-score: uint,
    reliability-score: uint,
    total-requests: uint,
    successful-signatures: uint,
    failed-signatures: uint,
    average-response-time: uint,
    last-activity: uint
})

;; Track multisig wallets and their authorized signers
(define-map multisig-wallets principal {
    signers: (list 20 principal),
    required-signatures: uint,
    total-transactions: uint,
    successful-transactions: uint
})

;; Track individual signature events
(define-map signature-events {signer: principal, tx-id: uint} {
    multisig-wallet: principal,
    signed: bool,
    response-time: uint,
    block-height: uint
})

;; public functions
;;

;; Initialize a multisig wallet with signers
(define-public (register-multisig (signers (list 20 principal)) (required-sigs uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (asserts! (> (len signers) u0) (err u104))
        (asserts! (<= required-sigs (len signers)) (err u105))
        (map-set multisig-wallets tx-sender {
            signers: signers,
            required-signatures: required-sigs,
            total-transactions: u0,
            successful-transactions: u0
        })
        ;; Initialize scores for new signers
        (map initialize-signer-score signers)
        (ok true)
    )
)

;; Record a signature event
(define-public (record-signature (signer principal) (tx-id uint) (multisig-wallet principal) (signed bool) (response-time uint))
    (let (
        (current-block block-height)
        (existing-score (default-to {
            responsiveness-score: u50,
            reliability-score: u50,
            total-requests: u0,
            successful-signatures: u0,
            failed-signatures: u0,
            average-response-time: u0,
            last-activity: u0
        } (map-get? signer-scores signer)))
    )
        (asserts! (is-authorized-caller multisig-wallet) ERR_NOT_AUTHORIZED)

        ;; Record the signature event
        (map-set signature-events {signer: signer, tx-id: tx-id} {
            multisig-wallet: multisig-wallet,
            signed: signed,
            response-time: response-time,
            block-height: current-block
        })

        ;; Update signer scores
        (map-set signer-scores signer (update-signer-scores existing-score signed response-time))

        (ok true)
    )
)

;; Update multisig transaction stats
(define-public (record-transaction-completion (multisig-wallet principal) (successful bool))
    (let (
        (wallet-data (unwrap! (map-get? multisig-wallets multisig-wallet) ERR_MULTISIG_NOT_FOUND))
    )
        (asserts! (is-authorized-caller multisig-wallet) ERR_NOT_AUTHORIZED)

        (map-set multisig-wallets multisig-wallet (merge wallet-data {
            total-transactions: (+ (get total-transactions wallet-data) u1),
            successful-transactions: (if successful
                (+ (get successful-transactions wallet-data) u1)
                (get successful-transactions wallet-data)
            )
        }))
        (ok true)
    )
)

;; Admin function to manually adjust scores
(define-public (adjust-signer-score (signer principal) (responsiveness uint) (reliability uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (asserts! (<= responsiveness MAX_SCORE) ERR_INVALID_SCORE)
        (asserts! (<= reliability MAX_SCORE) ERR_INVALID_SCORE)

        (let (
            (existing-score (default-to {
                responsiveness-score: u50,
                reliability-score: u50,
                total-requests: u0,
                successful-signatures: u0,
                failed-signatures: u0,
                average-response-time: u0,
                last-activity: u0
            } (map-get? signer-scores signer)))
        )
            (map-set signer-scores signer (merge existing-score {
                responsiveness-score: responsiveness,
                reliability-score: reliability,
                last-activity: block-height
            }))
            (ok true)
        )
    )
)

;; read only functions
;;

;; Get signer reputation score
(define-read-only (get-signer-score (signer principal))
    (map-get? signer-scores signer)
)

;; Get multisig wallet information
(define-read-only (get-multisig-info (wallet principal))
    (map-get? multisig-wallets wallet)
)

;; Get signature event details
(define-read-only (get-signature-event (signer principal) (tx-id uint))
    (map-get? signature-events {signer: signer, tx-id: tx-id})
)

;; Calculate overall reputation score (weighted average)
(define-read-only (get-overall-reputation (signer principal))
    (match (map-get? signer-scores signer)
        score-data
        (let (
            (responsiveness (get responsiveness-score score-data))
            (reliability (get reliability-score score-data))
            ;; Weight: 60% responsiveness, 40% reliability
            (weighted-score (/ (+ (* responsiveness u60) (* reliability u40)) u100))
        )
            (ok weighted-score)
        )
        ERR_SIGNER_NOT_FOUND
    )
)

;; Get top signers by overall reputation
(define-read-only (is-reliable-signer (signer principal) (min-score uint))
    (match (get-overall-reputation signer)
        score (ok (>= score min-score))
        error (err error)
    )
)

;; Check if caller is authorized (multisig wallet or contract owner)
(define-read-only (is-authorized-caller (multisig-wallet principal))
    (or
        (is-eq tx-sender (var-get contract-owner))
        (is-eq tx-sender multisig-wallet)
    )
)

;; private functions
;;

;; Initialize signer score for new signers
(define-private (initialize-signer-score (signer principal))
    (if (is-none (map-get? signer-scores signer))
        (map-set signer-scores signer {
            responsiveness-score: u50,
            reliability-score: u50,
            total-requests: u0,
            successful-signatures: u0,
            failed-signatures: u0,
            average-response-time: u0,
            last-activity: block-height
        })
        false
    )
)

;; Update signer scores based on new signature event
(define-private (update-signer-scores (current-scores {responsiveness-score: uint, reliability-score: uint, total-requests: uint, successful-signatures: uint, failed-signatures: uint, average-response-time: uint, last-activity: uint}) (signed bool) (response-time uint))
    (let (
        (total-requests (+ (get total-requests current-scores) u1))
        (successful-sigs (if signed
            (+ (get successful-signatures current-scores) u1)
            (get successful-signatures current-scores)
        ))
        (failed-sigs (if signed
            (get failed-signatures current-scores)
            (+ (get failed-signatures current-scores) u1)
        ))
        (new-avg-response (calculate-new-average
            (get average-response-time current-scores)
            response-time
            total-requests
        ))
        ;; Calculate new reliability score (percentage of successful signatures)
        (new-reliability (if (> total-requests u0)
            (/ (* successful-sigs u100) total-requests)
            u50
        ))
        ;; Calculate new responsiveness score (inverse of average response time, capped at 100)
        (new-responsiveness (calculate-responsiveness-score new-avg-response))
    )
        {
            responsiveness-score: new-responsiveness,
            reliability-score: new-reliability,
            total-requests: total-requests,
            successful-signatures: successful-sigs,
            failed-signatures: failed-sigs,
            average-response-time: new-avg-response,
            last-activity: block-height
        }
    )
)

;; Calculate new average response time
(define-private (calculate-new-average (current-avg uint) (new-value uint) (count uint))
    (if (is-eq count u1)
        new-value
        (/ (+ (* current-avg (- count u1)) new-value) count)
    )
)

;; Calculate responsiveness score based on average response time
(define-private (calculate-responsiveness-score (avg-response-time uint))
    (if (is-eq avg-response-time u0)
        u100
        ;; Simple inverse relationship: faster response = higher score
        ;; Assuming response time is in blocks, good response is within 6 blocks (1 hour)
        (if (<= avg-response-time u6)
            u100
            (if (<= avg-response-time u144) ;; 24 hours
                (- u100 (/ (* (- avg-response-time u6) u80) u138))
                u20 ;; Minimum score for very slow responders
            )
        )
    )
)
