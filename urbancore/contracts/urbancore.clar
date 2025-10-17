;; Smart City Resource Management System
;; Manages city resources like parking, waste management, and energy

;; Constants
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INVALID-ASSET (err u2))
(define-constant ERR-ASSET-UNAVAILABLE (err u3))
(define-constant ERR-BAD-PARAMS (err u4))
(define-constant ERR-LOW-BALANCE (err u5))
(define-constant ERR-SENSOR-NOT-FOUND (err u6))
(define-constant ERR-BAD-CAPACITY (err u7))
(define-constant ERR-BAD-PRICE (err u8))
(define-constant ERR-BAD-LOCATION (err u9))
(define-constant ERR-BAD-VEHICLE (err u10))
(define-constant ERR-BAD-SENSOR (err u11))

;; Resource Types
(define-constant ASSET-TYPE-PARKING u1)
(define-constant ASSET-TYPE-WASTE u2)
(define-constant ASSET-TYPE-POWER u3)

;; Configuration Constants
(define-constant MAX-ALLOCATION u1000000)
(define-constant MAX-COST u1000000000)

;; Data Variables
(define-data-var system-admin principal tx-sender)
(define-data-var asset-count uint u0)
(define-data-var min-parking-cost uint u1000) ;; in microSTX
(define-data-var power-rate uint u100) ;; cost per kWh in microSTX

;; Maps
(define-map assets
    uint
    {
        asset-type: uint,
        address: (string-utf8 64),
        allocation: uint,
        available-units: uint,
        active: bool,
        cost: uint
    }
)

(define-map parking-spaces
    uint
    {
        space-id: uint,
        is-occupied: bool,
        vehicle-identifier: (optional (string-utf8 32)),
        expiration-height: uint
    }
)

(define-map waste-containers
    uint
    {
        container-id: uint,
        capacity-level: uint,
        last-serviced: uint,
        requires-maintenance: bool
    }
)

(define-map power-allocation
    {asset-id: uint, user: principal}
    {
        reserved: uint,
        consumed: uint,
        last-modified: uint
    }
)

(define-map sensors
    principal
    {
        sensor-id: (string-utf8 32),
        sensor-type: uint,
        asset-id: uint,
        active: bool,
        last-heartbeat: uint,
        is-authorized: bool
    }
)

;; Validation Functions
(define-private (validate-address (address (string-utf8 64)))
    (> (len address) u0))

(define-private (validate-allocation (allocation uint))
    (and (> allocation u0) (<= allocation MAX-ALLOCATION)))

(define-private (validate-cost (cost uint))
    (and (> cost u0) (<= cost MAX-COST)))

(define-private (validate-vehicle-identifier (vehicle-identifier (string-utf8 32)))
    (> (len vehicle-identifier) u0))

(define-private (validate-sensor-id (sensor-id (string-utf8 32)))
    (> (len sensor-id) u0))

;; Authorization
(define-private (is-system-admin)
    (is-eq tx-sender (var-get system-admin)))

(define-private (is-authorized-sensor)
    (match (map-get? sensors tx-sender)
        sensor (get is-authorized sensor)
        false))

;; Resource Management Functions
(define-public (register-resource 
    (asset-type uint)
    (address (string-utf8 64))
    (allocation uint)
    (cost uint))
    (begin
        (asserts! (is-system-admin) ERR-UNAUTHORIZED)
        (asserts! (validate-address address) ERR-BAD-LOCATION)
        (asserts! (validate-allocation allocation) ERR-BAD-CAPACITY)
        (asserts! (validate-cost cost) ERR-BAD-PRICE)
        (asserts! (or 
            (is-eq asset-type ASSET-TYPE-PARKING)
            (is-eq asset-type ASSET-TYPE-WASTE)
            (is-eq asset-type ASSET-TYPE-POWER))
            ERR-INVALID-ASSET)
        
        (let ((asset-id (var-get asset-count)))
            (map-set assets asset-id
                {
                    asset-type: asset-type,
                    address: address,
                    allocation: allocation,
                    available-units: allocation,
                    active: true,
                    cost: cost
                })
            (var-set asset-count (+ asset-id u1))
            (ok asset-id))))

;; Parking Management
(define-public (reserve-parking 
    (asset-id uint)
    (vehicle-identifier (string-utf8 32))
    (duration uint))
    (let (
        (asset (unwrap! (map-get? assets asset-id) ERR-INVALID-ASSET))
        (parking-fee (* (get cost asset) duration))
        )
        (asserts! (validate-vehicle-identifier vehicle-identifier) ERR-BAD-VEHICLE)
        (asserts! (>= (get available-units asset) u1) ERR-ASSET-UNAVAILABLE)
        (asserts! (>= parking-fee (var-get min-parking-cost)) ERR-LOW-BALANCE)
        
        ;; Process payment
        (try! (stx-transfer? parking-fee tx-sender (var-get system-admin)))
        
        ;; Update parking spot
        (map-set parking-spaces asset-id
            {
                space-id: asset-id,
                is-occupied: true,
                vehicle-identifier: (some vehicle-identifier),
                expiration-height: (+ block-height duration)
            })
        
        ;; Update resource availability
        (map-set assets asset-id
            (merge asset {available-units: (- (get available-units asset) u1)}))
        
        (ok true)))

;; Waste Management
(define-public (update-waste-level
    (asset-id uint)
    (capacity-level uint))
    (begin
        (asserts! (is-authorized-sensor) ERR-UNAUTHORIZED)
        (asserts! (<= capacity-level u100) ERR-BAD-PARAMS)
        (asserts! (is-some (map-get? assets asset-id)) ERR-INVALID-ASSET)
        
        (match (map-get? waste-containers asset-id)
            container (begin
                (map-set waste-containers asset-id
                    (merge container {
                        capacity-level: capacity-level,
                        requires-maintenance: (> capacity-level u80),
                        last-serviced: block-height
                    }))
                (ok true))
            ERR-INVALID-ASSET)))

;; Energy Management
(define-public (allocate-power
    (asset-id uint)
    (amount uint))
    (let (
        (asset (unwrap! (map-get? assets asset-id) ERR-INVALID-ASSET))
        (energy-cost (* amount (var-get power-rate)))
        )
        (asserts! (validate-allocation amount) ERR-BAD-CAPACITY)
        (asserts! (>= (get available-units asset) amount) ERR-ASSET-UNAVAILABLE)
        
        ;; Process payment
        (try! (stx-transfer? energy-cost tx-sender (var-get system-admin)))
        
        ;; Update energy allocation
        (map-set power-allocation
            {asset-id: asset-id, user: tx-sender}
            {
                reserved: amount,
                consumed: u0,
                last-modified: block-height
            })
        
        (map-set assets asset-id
            (merge asset {available-units: (- (get available-units asset) amount)}))
        
        (ok true)))

;; IoT Device Management
(define-public (register-device
    (sensor-id (string-utf8 32))
    (sensor-type uint)
    (asset-id uint))
    (begin
        (asserts! (is-system-admin) ERR-UNAUTHORIZED)
        (asserts! (validate-sensor-id sensor-id) ERR-BAD-SENSOR)
        (asserts! (is-some (map-get? assets asset-id)) ERR-INVALID-ASSET)
        (asserts! (or 
            (is-eq sensor-type ASSET-TYPE-PARKING)
            (is-eq sensor-type ASSET-TYPE-WASTE)
            (is-eq sensor-type ASSET-TYPE-POWER))
            ERR-INVALID-ASSET)
        
        (map-set sensors tx-sender
            {
                sensor-id: sensor-id,
                sensor-type: sensor-type,
                asset-id: asset-id,
                active: true,
                last-heartbeat: block-height,
                is-authorized: true
            })
        (ok true)))

(define-public (deactivate-device (sensor-principal principal))
    (begin
        (asserts! (is-system-admin) ERR-UNAUTHORIZED)
        (asserts! (is-some (map-get? sensors sensor-principal)) ERR-SENSOR-NOT-FOUND)
        
        (match (map-get? sensors sensor-principal)
            sensor (begin
                (map-set sensors sensor-principal
                    (merge sensor {active: false, is-authorized: false}))
                (ok true))
            ERR-SENSOR-NOT-FOUND)))

(define-public (update-device-heartbeat)
    (match (map-get? sensors tx-sender)
        sensor (begin
            (map-set sensors tx-sender
                (merge sensor {last-heartbeat: block-height}))
            (ok true))
        ERR-SENSOR-NOT-FOUND))

;; Read-only functions
(define-read-only (get-resource-info (asset-id uint))
    (map-get? assets asset-id))

(define-read-only (get-parking-info (asset-id uint))
    (map-get? parking-spaces asset-id))

(define-read-only (get-waste-info (asset-id uint))
    (map-get? waste-containers asset-id))

(define-read-only (get-power-consumption (asset-id uint) (user principal))
    (map-get? power-allocation {asset-id: asset-id, user: user}))

(define-read-only (get-device-status (sensor-principal principal))
    (map-get? sensors sensor-principal))