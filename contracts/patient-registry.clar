;; Patient Registration Contract
;; Securely stores anonymized patient data for rare disease registry

;; Data structures
(define-map patients
  { patient-id: (buff 32) }
  {
    registration-date: uint,
    demographic-hash: (buff 32),
    consent-status: bool,
    data-access-policy: (buff 32)
  }
)

(define-map patient-identifiers
  { principal-id: principal }
  { patient-id: (buff 32) }
)

(define-map data-access
  { patient-id: (buff 32), accessor: principal }
  { can-read: bool, can-write: bool }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_REGISTERED u2)
(define-constant ERR_NOT_FOUND u3)

;; Read-only functions
(define-read-only (get-patient-data (patient-id (buff 32)))
  (match (map-get? patients { patient-id: patient-id })
    data (ok data)
    (err ERR_NOT_FOUND)
  )
)

(define-read-only (get-patient-id (principal-id principal))
  (match (map-get? patient-identifiers { principal-id: principal-id })
    data (ok (get patient-id data))
    (err ERR_NOT_FOUND)
  )
)

(define-read-only (can-access (patient-id (buff 32)) (accessor principal))
  (match (map-get? data-access { patient-id: patient-id, accessor: accessor })
    access (ok access)
    (err ERR_UNAUTHORIZED)
  )
)

;; Public functions
(define-public (register-patient
    (patient-id (buff 32))
    (demographic-hash (buff 32))
    (data-access-policy (buff 32)))
  (let
    (
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? patient-identifiers { principal-id: caller })) (err ERR_ALREADY_REGISTERED))

    ;; Store patient data
    (map-set patients
      { patient-id: patient-id }
      {
        registration-date: block-height,
        demographic-hash: demographic-hash,
        consent-status: true,
        data-access-policy: data-access-policy
      }
    )

    ;; Map principal to patient ID
    (map-set patient-identifiers
      { principal-id: caller }
      { patient-id: patient-id }
    )

    ;; Grant access to self
    (map-set data-access
      { patient-id: patient-id, accessor: caller }
      { can-read: true, can-write: true }
    )

    (ok patient-id)
  )
)

(define-public (update-consent (patient-id (buff 32)) (consent-status bool))
  (let
    (
      (caller tx-sender)
    )
    ;; Check if caller has write access
    (match (map-get? data-access { patient-id: patient-id, accessor: caller })
      access (begin
        (asserts! (get can-write access) (err ERR_UNAUTHORIZED))

        ;; Get current patient data
        (match (map-get? patients { patient-id: patient-id })
          patient-data (begin
            ;; Update consent status
            (map-set patients
              { patient-id: patient-id }
              (merge patient-data { consent-status: consent-status })
            )
            (ok true)
          )
          (err ERR_NOT_FOUND)
        )
      )
      (err ERR_UNAUTHORIZED)
    )
  )
)

(define-public (grant-access (patient-id (buff 32)) (accessor principal) (can-read bool) (can-write bool))
  (let
    (
      (caller tx-sender)
    )
    ;; Check if caller has write access
    (match (map-get? data-access { patient-id: patient-id, accessor: caller })
      access (begin
        (asserts! (get can-write access) (err ERR_UNAUTHORIZED))

        ;; Grant access to specified principal
        (map-set data-access
          { patient-id: patient-id, accessor: accessor }
          { can-read: can-read, can-write: can-write }
        )
        (ok true)
      )
      (err ERR_UNAUTHORIZED)
    )
  )
)

(define-public (revoke-access (patient-id (buff 32)) (accessor principal))
  (let
    (
      (caller tx-sender)
    )
    ;; Check if caller has write access
    (match (map-get? data-access { patient-id: patient-id, accessor: caller })
      access (begin
        (asserts! (get can-write access) (err ERR_UNAUTHORIZED))

        ;; Revoke access
        (map-delete data-access { patient-id: patient-id, accessor: accessor })
        (ok true)
      )
      (err ERR_UNAUTHORIZED)
    )
  )
)

