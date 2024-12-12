;; SatoshiLend: Bitcoin-Backed Lending Platform
;; A decentralized lending platform allowing users to take loans using Bitcoin as collateral

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-INSUFFICIENT-FUNDS (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-LOAN-NOT-FOUND (err u102))
(define-constant ERR-LOAN-ALREADY-EXISTS (err u103))
(define-constant ERR-LOAN-REPAYMENT-FAILED (err u104))
(define-constant ERR-LIQUIDATION-NOT-ALLOWED (err u105))
(define-constant ERR-INVALID-PARAMETER (err u106))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u107))

;; Maximum values to prevent overflow
(define-constant MAX-INTEREST-RATE u10000) ;; 100.00%
(define-constant MAX-LOAN-DURATION u52560) ;; Approximately 1 year in blocks
(define-constant MAX-UINT u340282366920938463463374607431768211455)
(define-constant COLLATERAL-RATIO u150) ;; 150% minimum collateralization ratio

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

;; Internal Functions
(define-private (validate-loan-parameters 
    (collateral-amount uint)
    (loan-amount uint)
    (interest-rate uint)
    (loan-duration uint)
  )
  (and
    (> collateral-amount u0)
    (<= collateral-amount MAX-UINT)
    (> loan-amount u0)
    (<= loan-amount MAX-UINT)
    (<= interest-rate MAX-INTEREST-RATE)
    (> loan-duration u0)
    (<= loan-duration MAX-LOAN-DURATION)
  )
)

;; Validate loan ID exists and belongs to the borrower
(define-private (validate-loan-ownership (loan-id uint))
  (is-some 
    (map-get? loans {
      loan-id: loan-id, 
      borrower: tx-sender
    })
  )
)

;; Calculate minimum required collateral for a loan
(define-private (calculate-min-collateral (loan-amount uint))
  (/ (* loan-amount COLLATERAL-RATIO) u100)
)

;; Read-only Functions
(define-read-only (get-loan-details (loan-id uint) (borrower principal))
  (map-get? loans {loan-id: loan-id, borrower: borrower})
)

(define-read-only (get-loan-repayment-status (loan-id uint) (borrower principal))
  (map-get? loan-repayments {loan-id: loan-id, borrower: borrower})
)

;; Public Functions
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
    (asserts! 
      (validate-loan-parameters 
        collateral-amount 
        loan-amount 
        interest-rate 
        loan-duration
      ) 
      ERR-INVALID-PARAMETER
    )
    
    ;; Check if loan already exists
    (asserts! 
      (is-none 
        (map-get? loans {loan-id: new-loan-id, borrower: tx-sender})
      ) 
      ERR-LOAN-ALREADY-EXISTS
    )
    
    ;; Validate collateral amount
    (asserts! 
      (>= collateral-amount (calculate-min-collateral loan-amount)) 
      ERR-INSUFFICIENT-COLLATERAL
    )
    
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

(define-public (add-collateral (loan-id uint) (additional-amount uint))
  (let
    (
      ;; Validate loan ownership first
      (loan-exists (asserts! 
        (validate-loan-ownership loan-id) 
        ERR-UNAUTHORIZED
      ))
      
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: tx-sender}) 
        ERR-LOAN-NOT-FOUND
      ))
    )
    ;; Validate loan is active
    (asserts! (get is-active loan) ERR-UNAUTHORIZED)
    
    ;; Validate additional collateral amount
    (asserts! (> additional-amount u0) ERR-INVALID-PARAMETER)
    
    ;; Check that new total collateral won't overflow
    (let
      (
        (new-collateral-amount (+ (get collateral-amount loan) additional-amount))
      )
      (asserts! (<= new-collateral-amount MAX-UINT) ERR-INVALID-PARAMETER)
      
      ;; Update loan with new collateral amount
      (map-set loans 
        {loan-id: loan-id, borrower: tx-sender}
        (merge loan {collateral-amount: new-collateral-amount})
      )
      
      (ok new-collateral-amount)
    )
  )
)

(define-public (withdraw-collateral (loan-id uint) (withdraw-amount uint))
  (let
    (
      ;; Validate loan ownership first
      (loan-exists (asserts! 
        (validate-loan-ownership loan-id) 
        ERR-UNAUTHORIZED
      ))
      
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: tx-sender}) 
        ERR-LOAN-NOT-FOUND
      ))
    )
    ;; Validate loan exists and is active
    (asserts! (get is-active loan) ERR-UNAUTHORIZED)
    
    ;; Validate withdrawal amount
    (asserts! (> withdraw-amount u0) ERR-INVALID-PARAMETER)
    (asserts! (<= withdraw-amount (get collateral-amount loan)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Calculate new collateral amount after withdrawal
    (let
      (
        (new-collateral-amount (- (get collateral-amount loan) withdraw-amount))
        (min-required-collateral (calculate-min-collateral (get loan-amount loan)))
      )
      ;; Ensure remaining collateral meets minimum requirement
      (asserts! (>= new-collateral-amount min-required-collateral) ERR-INSUFFICIENT-COLLATERAL)
      
      ;; Update loan with new collateral amount
      (map-set loans 
        {loan-id: loan-id, borrower: tx-sender}
        (merge loan {collateral-amount: new-collateral-amount})
      )
      
      (ok withdraw-amount)
    )
  )
)

(define-public (repay-loan (loan-id uint))
  (let 
    (
      ;; Validate loan ownership first
      (loan-exists (asserts! 
        (validate-loan-ownership loan-id) 
        ERR-UNAUTHORIZED
      ))
      
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: tx-sender}) 
        ERR-LOAN-NOT-FOUND
      ))
      (current-repayments (default-to 
        {total-repaid: u0} 
        (map-get? loan-repayments {loan-id: loan-id, borrower: tx-sender})
      ))
    )
    ;; Validate loan exists and is active
    (asserts! (get is-active loan) ERR-UNAUTHORIZED)
    
    ;; Calculate total repayment amount with interest
    (let 
      (
        (total-repayment (+ 
          (get loan-amount loan)
          (/ (* (get loan-amount loan) (get interest-rate loan)) u100)
        ))
      )
      ;; Validate repayment amount doesn't overflow
      (asserts! (<= total-repayment MAX-UINT) ERR-LOAN-REPAYMENT-FAILED)
      
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

(define-public (liquidate-loan (loan-id uint))
  (let 
    (
      ;; Validate loan ownership first
      (loan-exists (asserts! 
        (validate-loan-ownership loan-id) 
        ERR-UNAUTHORIZED
      ))
      
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: tx-sender}) 
        ERR-LOAN-NOT-FOUND
      ))
    )
    ;; Validate loan exists
    (asserts! (get is-active loan) ERR-UNAUTHORIZED)
    
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