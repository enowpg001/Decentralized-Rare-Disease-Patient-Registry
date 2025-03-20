;; Patient Registration Contract
;; Securely stores anonymized patient data

;; Define data variables
(define-data-var registry-admin principal tx-sender)
(define-map patients
  { patient-id: (buff 32) }
  {
    demographic-hash: (buff 32),
    diagnosis-hash: (buff 32),
    consent-status: bool,
    created-at: uint,
    updated-at: uint
  }
)

;; Define data access control
(define-map data-access-permissions
  { patient-id: (buff 32), accessor: principal }
  { can-read: bool, can-update: bool, expiration: uint }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_PATIENT_EXISTS u2)
(define-constant ERR_PATIENT_NOT_FOUND u3)
(define-constant ERR_INVALID_DATA u4)
(define-constant ERR_EXPIRED_PERMISSION u5)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get registry-admin))
)

;; Register a new patient
(define-public (register-patient
                (patient-id (buff 32))
                (demographic-hash (buff 32))
                (diagnosis-hash (buff 32)))
  (begin
    ;; Check if patient already exists
    (asserts! (is-none (map-get? patients { patient-id: patient-id }))
              (err ERR_PATIENT_EXISTS))

    ;; Insert new patient record
    (map-set patients
      { patient-id: patient-id }
      {
        demographic-hash: demographic-hash,
        diagnosis-hash: diagnosis-hash,
        consent-status: true,
        created-at: block-height,
        updated-at: block-height
      }
    )

    ;; Grant access to the patient (tx-sender)
    (map-set data-access-permissions
      { patient-id: patient-id, accessor: tx-sender }
      { can-read: true, can-update: true, expiration: u0 }
    )

    (ok true)
  )
)

;; Update patient data
(define-public (update-patient-data
                (patient-id (buff 32))
                (demographic-hash (buff 32))
                (diagnosis-hash (buff 32)))
  (let ((patient-data (map-get? patients { patient-id: patient-id }))
        (access-permission (map-get? data-access-permissions { patient-id: patient-id, accessor: tx-sender })))

    ;; Check if patient exists
    (asserts! (is-some patient-data) (err ERR_PATIENT_NOT_FOUND))

    ;; Check if caller has permission
    (asserts! (and (is-some access-permission)
                  (get can-update (unwrap! access-permission (err ERR_UNAUTHORIZED)))
                  (or (is-eq (get expiration (unwrap! access-permission (err ERR_UNAUTHORIZED))) u0)
                      (< block-height (get expiration (unwrap! access-permission (err ERR_UNAUTHORIZED))))))
              (err ERR_UNAUTHORIZED))

    ;; Update patient data
    (map-set patients
      { patient-id: patient-id }
      {
        demographic-hash: demographic-hash,
        diagnosis-hash: diagnosis-hash,
        consent-status: (get consent-status (unwrap! patient-data (err ERR_PATIENT_NOT_FOUND))),
        created-at: (get created-at (unwrap! patient-data (err ERR_PATIENT_NOT_FOUND))),
        updated-at: block-height
      }
    )

    (ok true)
  )
)

;; Update consent status
(define-public (update-consent
                (patient-id (buff 32))
                (new-consent-status bool))
  (let ((patient-data (map-get? patients { patient-id: patient-id }))
        (access-permission (map-get? data-access-permissions { patient-id: patient-id, accessor: tx-sender })))

    ;; Check if patient exists
    (asserts! (is-some patient-data) (err ERR_PATIENT_NOT_FOUND))

    ;; Check if caller has permission
    (asserts! (and (is-some access-permission)
                  (get can-update (unwrap! access-permission (err ERR_UNAUTHORIZED))))
              (err ERR_UNAUTHORIZED))

    ;; Update consent status
    (map-set patients
      { patient-id: patient-id }
      {
        demographic-hash: (get demographic-hash (unwrap! patient-data (err ERR_PATIENT_NOT_FOUND))),
        diagnosis-hash: (get diagnosis-hash (unwrap! patient-data (err ERR_PATIENT_NOT_FOUND))),
        consent-status: new-consent-status,
        created-at: (get created-at (unwrap! patient-data (err ERR_PATIENT_NOT_FOUND))),
        updated-at: block-height
      }
    )

    (ok true)
  )
)

;; Grant data access to a third party
(define-public (grant-access
                (patient-id (buff 32))
                (accessor principal)
                (can-read bool)
                (can-update bool)
                (expiration uint))
  (let ((patient-data (map-get? patients { patient-id: patient-id }))
        (access-permission (map-get? data-access-permissions { patient-id: patient-id, accessor: tx-sender })))

    ;; Check if patient exists
    (asserts! (is-some patient-data) (err ERR_PATIENT_NOT_FOUND))

    ;; Check if caller has permission to manage access
    (asserts! (and (is-some access-permission)
                  (get can-update (unwrap! access-permission (err ERR_UNAUTHORIZED))))
              (err ERR_UNAUTHORIZED))

    ;; Grant access to the specified accessor
    (map-set data-access-permissions
      { patient-id: patient-id, accessor: accessor }
      { can-read: can-read, can-update: can-update, expiration: expiration }
    )

    (ok true)
  )
)

;; Revoke data access from a third party
(define-public (revoke-access
                (patient-id (buff 32))
                (accessor principal))
  (let ((patient-data (map-get? patients { patient-id: patient-id }))
        (access-permission (map-get? data-access-permissions { patient-id: patient-id, accessor: tx-sender })))

    ;; Check if patient exists
    (asserts! (is-some patient-data) (err ERR_PATIENT_NOT_FOUND))

    ;; Check if caller has permission to manage access
    (asserts! (and (is-some access-permission)
                  (get can-update (unwrap! access-permission (err ERR_UNAUTHORIZED))))
              (err ERR_UNAUTHORIZED))

    ;; Revoke access
    (map-delete data-access-permissions { patient-id: patient-id, accessor: accessor })

    (ok true)
  )
)

;; Read patient data (only if authorized)
(define-read-only (get-patient-data (patient-id (buff 32)))
  (let ((patient-data (map-get? patients { patient-id: patient-id }))
        (access-permission (map-get? data-access-permissions { patient-id: patient-id, accessor: tx-sender })))

    ;; Check if patient exists
    (asserts! (is-some patient-data) (err ERR_PATIENT_NOT_FOUND))

    ;; Check if caller has permission to read
    (asserts! (and (is-some access-permission)
                  (get can-read (unwrap! access-permission (err ERR_UNAUTHORIZED)))
                  (or (is-eq (get expiration (unwrap! access-permission (err ERR_UNAUTHORIZED))) u0)
                      (< block-height (get expiration (unwrap! access-permission (err ERR_UNAUTHORIZED))))))
              (err ERR_UNAUTHORIZED))

    ;; Return patient data
    (ok (unwrap! patient-data (err ERR_PATIENT_NOT_FOUND)))
  )
)

