;; -----------------------------------------
;; STX AutoSplit - Automated Revenue Splitter
;; -----------------------------------------

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_ALLOCATION (err u1001))
(define-constant ERR_INVALID_AMOUNT (err u1002))
(define-constant ERR_TRANSFER_FAILED (err u1003))
(define-constant ERR_NO_BALANCE (err u1004))
(define-constant ERR_WITHDRAWAL_FAILED (err u1005))
(define-constant ERR_NOT_RECIPIENT (err u1006))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1007))

(define-data-var owner principal tx-sender) ;; Contract owner
(define-data-var recipient-list (list 100 principal) (list)) ;; Stores recipient addresses

(define-map recipients 
  { recipient: principal } 
  { share: uint, balance: uint }
)

;; -------- Add or Update Recipient --------
(define-public (set-recipient (recipient principal) (percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED) ;; Only owner can manage recipients
    (asserts! (> percentage u0) ERR_INVALID_AMOUNT) ;; Ensure positive percentage
    (asserts! (<= percentage u100) ERR_INVALID_ALLOCATION) ;; Ensure percentage <= 100%

    ;; Check if recipient already exists
    (let ((existing-recipient (map-get? recipients { recipient: recipient })))
      (match existing-recipient
        existing-data
        ;; Update existing recipient
        (begin
          (map-set recipients { recipient: recipient } { share: percentage, balance: (get balance existing-data) })
          (ok true)
        )
        ;; Add new recipient
        (begin
          ;; Check total allocation
          (let ((current-total (fold get-total-shares (var-get recipient-list) u0)))
            (asserts! (<= (+ current-total percentage) u100) ERR_INVALID_ALLOCATION)
            ;; Add to recipient list
            (var-set recipient-list 
              (unwrap! (as-max-len? (append (var-get recipient-list) recipient) u100) ERR_INVALID_ALLOCATION))
            ;; Add to recipients map
            (map-set recipients { recipient: recipient } { share: percentage, balance: u0 })
            (ok true)
          )
        )
      )
    )
  )
)

;; Helper function to calculate total shares
(define-private (get-total-shares (recipient principal) (acc uint))
  (match (map-get? recipients { recipient: recipient })
    recipient-data (+ acc (get share recipient-data))
    acc
  )
)

;; -------- Remove Recipient --------
(define-public (remove-recipient (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? recipients { recipient: recipient })) ERR_NOT_RECIPIENT)
    
    ;; Remove from recipients map
    (map-delete recipients { recipient: recipient })
    
    ;; Remove from recipient list
    (var-set recipient-list (filter is-not-target-recipient (var-get recipient-list)))
    (ok true)
  )
)

;; Helper function for filtering out removed recipient
(define-private (is-not-target-recipient (current-recipient principal))
  (not (is-eq current-recipient tx-sender))
)

;; -------- Deposit & Auto-Split Funds --------
(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT) ;; Ensure positive deposit
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE) ;; Ensure sender has enough balance

    ;; Transfer funds to contract
    (unwrap! (stx-transfer? amount tx-sender (as-contract tx-sender)) ERR_TRANSFER_FAILED)
    
    ;; Distribute funds to all recipients
    (fold distribute-funds (var-get recipient-list) amount)
    (ok true)
  )
)

;; Helper function to distribute funds to all recipients
(define-private (distribute-funds (recipient principal) (amount uint))
  (match (map-get? recipients { recipient: recipient })
    recipient-data
      (let ((share (get share recipient-data))
            (allocated (/ (* amount share) u100)))
        (map-set recipients { recipient: recipient } 
          { share: share, balance: (+ (get balance recipient-data) allocated) })
        amount)  ;; Return the amount unchanged for the next iteration
    amount)  ;; If recipient not found, return amount unchanged
)

;; -------- Withdraw Funds --------
(define-public (withdraw)
  (match (map-get? recipients { recipient: tx-sender })
    recipient-data
      (let ((amount (get balance recipient-data)))
        (asserts! (> amount u0) ERR_NO_BALANCE) ;; Ensure funds exist
        (unwrap! (as-contract (stx-transfer? amount tx-sender tx-sender)) ERR_WITHDRAWAL_FAILED)
        (map-set recipients { recipient: tx-sender } { share: (get share recipient-data), balance: u0 })
        (ok amount)
      )
    ERR_NOT_RECIPIENT ;; Not a recipient
  )
)

;; -------- Withdraw Specific Amount --------
(define-public (withdraw-amount (amount uint))
  (match (map-get? recipients { recipient: tx-sender })
    recipient-data
      (let ((available-balance (get balance recipient-data)))
        (asserts! (>= available-balance amount) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (unwrap! (as-contract (stx-transfer? amount tx-sender tx-sender)) ERR_WITHDRAWAL_FAILED)
        (map-set recipients { recipient: tx-sender } 
          { share: (get share recipient-data), balance: (- available-balance amount) })
        (ok amount)
      )
    ERR_NOT_RECIPIENT
  )
)

;; -------- Change Owner --------
(define-public (change-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set owner new-owner)
    (ok true)
  )
)

;; -------- Get Recipient Info --------
(define-read-only (get-recipient (recipient principal))
  (ok (map-get? recipients { recipient: recipient }))
)

;; -------- Get Total Allocation --------
(define-read-only (get-total-share)
  (ok (fold get-total-shares (var-get recipient-list) u0))
)

;; -------- Get Recipient List --------
(define-read-only (get-recipients)
  (ok (var-get recipient-list))
)

;; -------- Get Owner --------
(define-read-only (get-owner)
  (ok (var-get owner))
)

;; -------- Get Contract Balance --------
(define-read-only (get-contract-balance)
  (ok (stx-get-balance (as-contract tx-sender)))
)

;; -------- Get All Recipients with Details --------
(define-read-only (get-all-recipients-details)
  (ok (map get-recipient-details (var-get recipient-list)))
)

;; Helper function to get recipient details
(define-private (get-recipient-details (recipient principal))
  (match (map-get? recipients { recipient: recipient })
    recipient-data {
      recipient: recipient,
      share: (get share recipient-data),
      balance: (get balance recipient-data)
    }
    {
      recipient: recipient,
      share: u0,
      balance: u0
    }
  )
)

;; -------- Check if Principal is Recipient --------
(define-read-only (is-recipient (user principal))
  (ok (is-some (map-get? recipients { recipient: user })))
)