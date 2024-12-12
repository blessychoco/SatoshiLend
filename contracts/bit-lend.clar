;; Bitcoin-Backed Lending Platform Smart Contract

;; Errors
(define-constant ERR-INSUFFICIENT-FUNDS (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-LOAN-NOT-FOUND (err u102))
(define-constant ERR-LOAN-ALREADY-EXISTS (err u103))
(define-constant ERR-LOAN-REPAYMENT-FAILED (err u104))
(define-constant ERR-LIQUIDATION-NOT-ALLOWED (err u105))

;; Data Maps
(define-map loans 
  {
    loan-id: uint,
    borrower: principal
  }
  {
    collateral-amount: uint,
    loan-amount: uint,
    interest-rate: uint,
    loan-start-block: uint,
    loan-duration: uint,
    is-active: bool
  }
)

(define-map loan-repayments
  {
    loan-id: uint,
    borrower: principal
  }
  {
    total-repaid: uint
  }
)

;; Variables
(define-data-var next-loan-id uint u0)

;; Get Loan Details
(define-read-only (get-loan-details (loan-id uint) (borrower principal))
  (map-get? loans {loan-id: loan-id, borrower: borrower})
)

;; Create Loan
(define-public (create-loan 
  (collateral-amount uint)
  (loan-amount uint)
  (interest-rate uint)
  (loan-duration uint)
)
  (let 
    (
      (current-loan-id (var-get next-loan-id))
      (new-loan-id (+ current-loan-id u1))
    )
    ;; Validate loan parameters
    (asserts! (> collateral-amount u0) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> loan-amount u0) ERR-INSUFFICIENT-FUNDS)
    
    ;; Create loan entry
    (map-set loans 
      {loan-id: new-loan-id, borrower: tx-sender}
      {
        collateral-amount: collateral-amount,
        loan-amount: loan-amount,
        interest-rate: interest-rate,
        loan-start-block: block-height,
        loan-duration: loan-duration,
        is-active: true
      }
    )
    
    ;; Update next loan ID
    (var-set next-loan-id new-loan-id)
    
    ;; Return loan ID
    (ok new-loan-id)
  )
)

;; Repay Loan
(define-public (repay-loan (loan-id uint))
  (let 
    (
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: tx-sender}) 
        ERR-LOAN-NOT-FOUND
      ))
      (current-repayments (default-to {total-repaid: u0} 
        (map-get? loan-repayments {loan-id: loan-id, borrower: tx-sender})
      ))
    )
    ;; Validate loan is active
    (asserts! (get is-active loan) ERR-UNAUTHORIZED)
    
    ;; Calculate total repayment amount with interest
    (let 
      (
        (total-repayment (+ 
          (get loan-amount loan)
          (/ (* (get loan-amount loan) (get interest-rate loan)) u100)
        ))
      )
      ;; Update loan status
      (map-set loans 
        {loan-id: loan-id, borrower: tx-sender}
        (merge loan {is-active: false})
      )
      
      ;; Track repayments
      (map-set loan-repayments
        {loan-id: loan-id, borrower: tx-sender}
        {total-repaid: total-repayment}
      )
      
      (ok total-repayment)
    )
  )
)

;; Liquidate Loan
(define-public (liquidate-loan (loan-id uint))
  (let 
    (
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: tx-sender}) 
        ERR-LOAN-NOT-FOUND
      ))
    )
    ;; Check if loan is past due
    (asserts! 
      (> (- block-height (get loan-start-block loan)) 
         (get loan-duration loan)) 
      ERR-LIQUIDATION-NOT-ALLOWED
    )
    
    ;; Mark loan as inactive and allow liquidation
    (map-set loans 
      {loan-id: loan-id, borrower: tx-sender}
      (merge loan {is-active: false})
    )
    
    (ok true)
  )
)