# Urbancore

**Urbancore** is a smart city resource management system built in Clarity for automating urban resource operations such as parking allocation, waste monitoring, and energy distribution. It provides a decentralized, transparent framework for managing public utilities through blockchain-based resource registration, IoT integration, and on-chain payments.

## Overview

Urbancore integrates key municipal functions into one smart contract. Administrators can register assets like parking zones, waste bins, and power stations, while citizens and devices can interact autonomously with city infrastructure. The system ensures fair pricing, capacity validation, and real-time updates from authorized IoT sensors.

## Features

* **Asset Registration:** Administrators can register and configure resources across multiple categories.
* **Parking Management:** Enables drivers to book parking slots, make payments, and track expirations.
* **Waste Monitoring:** IoT sensors can report fill levels and flag bins needing service.
* **Energy Allocation:** Users can reserve energy capacity and pay for usage in microSTX.
* **Device Management:** Supports IoT sensor registration, deactivation, and heartbeat updates.
* **Access Control:** Only authorized devices and administrators can execute specific operations.

## Data Structures

* **resources:** Stores each city resource with details including type, location, capacity, availability, and price.
* **parking-slots:** Tracks slot occupancy, vehicle ID, and expiry time.
* **waste-bins:** Records fill levels, last emptied time, and service requirements.
* **energy-allocation:** Maps users to their allocated and used energy resources.
* **devices:** Maintains IoT device information, including authorization and activity status.

## Key Functions

* `register-asset`: Administrator registers a new parking, waste, or energy asset.
* `book-parking`: Citizens reserve parking spots and pay per duration.
* `update-trash-level`: Authorized devices update waste bin fill levels and trigger service alerts.
* `reserve-power`: Users reserve electricity by paying per kWh rate.
* `register-sensor`: Administrator registers and authorizes IoT devices for specific resources.
* `deactivate-sensor`: Disables a device’s authorization.
* `update-sensor-signal`: Updates a device’s activity timestamp.

## Read-Only Functions

* `get-asset-details`: Returns information on any resource by ID.
* `get-parking-status`: Displays parking slot occupancy and expiry details.
* `get-trash-container-status`: Provides waste bin status and service needs.
* `get-power-usage`: Retrieves user-specific energy allocation and consumption data.
* `get-sensor-status`: Checks the operational status of a registered device.

## Error Codes

* **u1:** Forbidden action, not an administrator or authorized device.
* **u2:** Invalid resource type.
* **u3:** Resource already occupied or unavailable.
* **u4:** Invalid parameters provided.
* **u5:** Insufficient balance for operation.
* **u6:** Device not found.
* **u7:** Invalid capacity value.
* **u8:** Invalid price input.
* **u9:** Invalid location string.
* **u10:** Invalid vehicle ID.
* **u11:** Invalid device ID.

## Usage Flow

1. **Administration:** Register assets and devices using `register-asset` and `register-sensor`.
2. **Citizens:** Book parking or reserve energy using `book-parking` and `reserve-power`.
3. **IoT Devices:** Report trash levels and keep sensor signals updated.
4. **Monitoring:** Query asset, usage, and sensor status using read-only endpoints.

## Security Notes

* All sensitive operations are restricted to administrators and authorized devices.
* Input validations ensure logical and financial integrity.
* IoT updates and user payments are recorded immutably on-chain.
