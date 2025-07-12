;; ArtisanCraftRegistry - Handmade craft authentication and provenance system

(define-map craft-items uint {
  artisan: principal,
  craft-title: (string-utf8 64),
  materials-used: (string-utf8 256),
  creation-timestamp: uint,
  workshop-location: (string-utf8 64),
  quality-verified: bool
})

(define-map artisan-portfolio principal (list 100 uint))
(define-map quality-inspectors principal bool)
(define-data-var craft-id-counter uint u0)

;; Error definitions
(define-constant err-unauthorized-artisan (err u300))
(define-constant err-unauthorized-inspector (err u301))
(define-constant err-craft-not-exists (err u302))
(define-constant err-permission-denied (err u403))
(define-constant err-portfolio-full (err u304))
(define-constant err-invalid-principal (err u305))
(define-constant err-empty-craft-title (err u306))
(define-constant err-empty-materials (err u307))
(define-constant err-invalid-timestamp (err u308))
(define-constant err-empty-workshop (err u309))
(define-constant err-invalid-craft-id (err u310))

;; Registry administrator
(define-constant registry-admin tx-sender)

;; Add quality inspector
(define-public (add-quality-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender registry-admin) err-permission-denied)
    (asserts! (not (is-eq inspector 'SP000000000000000000002Q6VF78)) err-invalid-principal)
    (ok (map-set quality-inspectors inspector true))
  ))

;; Register craft item
(define-public (register-craft-item
  (craft-title (string-utf8 64))
  (materials-used (string-utf8 256))
  (creation-timestamp uint)
  (workshop-location (string-utf8 64)))
  (let
    ((craft-id (var-get craft-id-counter))
     (artisan tx-sender)
     (existing-portfolio (default-to (list) (map-get? artisan-portfolio artisan))))
    
    (asserts! (> (len craft-title) u0) err-empty-craft-title)
    (asserts! (> (len materials-used) u0) err-empty-materials)
    (asserts! (> creation-timestamp u0) err-invalid-timestamp)
    (asserts! (> (len workshop-location) u0) err-empty-workshop)
    (asserts! (< (len existing-portfolio) u100) err-portfolio-full)
    
    (map-set craft-items craft-id {
      artisan: artisan,
      craft-title: craft-title,
      materials-used: materials-used,
      creation-timestamp: creation-timestamp,
      workshop-location: workshop-location,
      quality-verified: false
    })
    
    (let
      ((updated-portfolio (unwrap-panic (as-max-len? (concat (list craft-id) existing-portfolio) u100))))
      (map-set artisan-portfolio artisan updated-portfolio)
    )
    
    (var-set craft-id-counter (+ craft-id u1))
    (ok craft-id)))

;; Verify craft quality
(define-public (verify-craft-quality (craft-id uint))
  (begin
    (asserts! (< craft-id (var-get craft-id-counter)) err-invalid-craft-id)
    (let
      ((craft (unwrap! (map-get? craft-items craft-id) err-craft-not-exists)))
      (asserts! (default-to false (map-get? quality-inspectors tx-sender)) err-unauthorized-inspector)
      (ok (map-set craft-items craft-id (merge craft {quality-verified: true})))
    )
  ))

;; Get craft details
(define-read-only (get-craft-details (craft-id uint))
  (map-get? craft-items craft-id))

;; Get artisan portfolio
(define-read-only (get-artisan-portfolio (artisan principal))
  (default-to (list) (map-get? artisan-portfolio artisan)))

;; Check inspector status
(define-read-only (is-quality-inspector (address principal))
  (default-to false (map-get? quality-inspectors address)))
