import { describe, it, expect, beforeEach, vi } from "vitest"

// Mock the Clarity contract calls
const mockPatients = new Map()
const mockDataAccessPermissions = new Map()
let mockBlockHeight = 1

// Mock contract functions
const mockContractFunctions = {
  registerPatient: vi.fn((patientId, demographicHash, diagnosisHash) => {
    const patientKey = JSON.stringify({ patientId })
    if (mockPatients.has(patientKey)) {
      return { error: "ERR_PATIENT_EXISTS" }
    }
    
    mockPatients.set(patientKey, {
      demographicHash,
      diagnosisHash,
      consentStatus: true,
      createdAt: mockBlockHeight,
      updatedAt: mockBlockHeight,
    })
    
    // Grant access to the patient
    const accessKey = JSON.stringify({ patientId, accessor: "tx-sender" })
    mockDataAccessPermissions.set(accessKey, {
      canRead: true,
      canUpdate: true,
      expiration: 0,
    })
    
    return { value: true }
  }),
  
  updatePatientData: vi.fn((patientId, demographicHash, diagnosisHash) => {
    const patientKey = JSON.stringify({ patientId })
    const accessKey = JSON.stringify({ patientId, accessor: "tx-sender" })
    
    if (!mockPatients.has(patientKey)) {
      return { error: "ERR_PATIENT_NOT_FOUND" }
    }
    
    if (!mockDataAccessPermissions.has(accessKey) || !mockDataAccessPermissions.get(accessKey).canUpdate) {
      return { error: "ERR_UNAUTHORIZED" }
    }
    
    const patient = mockPatients.get(patientKey)
    mockPatients.set(patientKey, {
      ...patient,
      demographicHash,
      diagnosisHash,
      updatedAt: mockBlockHeight,
    })
    
    return { value: true }
  }),
  
  updateConsent: vi.fn((patientId, newConsentStatus) => {
    const patientKey = JSON.stringify({ patientId })
    const accessKey = JSON.stringify({ patientId, accessor: "tx-sender" })
    
    if (!mockPatients.has(patientKey)) {
      return { error: "ERR_PATIENT_NOT_FOUND" }
    }
    
    if (!mockDataAccessPermissions.has(accessKey) || !mockDataAccessPermissions.get(accessKey).canUpdate) {
      return { error: "ERR_UNAUTHORIZED" }
    }
    
    const patient = mockPatients.get(patientKey)
    mockPatients.set(patientKey, {
      ...patient,
      consentStatus: newConsentStatus,
      updatedAt: mockBlockHeight,
    })
    
    return { value: true }
  }),
  
  grantAccess: vi.fn((patientId, accessor, canRead, canUpdate, expiration) => {
    const patientKey = JSON.stringify({ patientId })
    const callerAccessKey = JSON.stringify({ patientId, accessor: "tx-sender" })
    
    if (!mockPatients.has(patientKey)) {
      return { error: "ERR_PATIENT_NOT_FOUND" }
    }
    
    if (!mockDataAccessPermissions.has(callerAccessKey) || !mockDataAccessPermissions.get(callerAccessKey).canUpdate) {
      return { error: "ERR_UNAUTHORIZED" }
    }
    
    const accessKey = JSON.stringify({ patientId, accessor })
    mockDataAccessPermissions.set(accessKey, {
      canRead,
      canUpdate,
      expiration,
    })
    
    return { value: true }
  }),
  
  getPatientData: vi.fn((patientId) => {
    const patientKey = JSON.stringify({ patientId })
    const accessKey = JSON.stringify({ patientId, accessor: "tx-sender" })
    
    if (!mockPatients.has(patientKey)) {
      return { error: "ERR_PATIENT_NOT_FOUND" }
    }
    
    if (!mockDataAccessPermissions.has(accessKey) || !mockDataAccessPermissions.get(accessKey).canRead) {
      return { error: "ERR_UNAUTHORIZED" }
    }
    
    return { value: mockPatients.get(patientKey) }
  }),
}

describe("Patient Registration Contract", () => {
  beforeEach(() => {
    // Reset mocks and state before each test
    mockPatients.clear()
    mockDataAccessPermissions.clear()
    mockBlockHeight = 1
    
    Object.values(mockContractFunctions).forEach((fn) => fn.mockClear())
  })
  
  it("should register a new patient successfully", () => {
    const patientId = "patient123"
    const demographicHash = "demo-hash"
    const diagnosisHash = "diagnosis-hash"
    
    const result = mockContractFunctions.registerPatient(patientId, demographicHash, diagnosisHash)
    
    expect(result).toEqual({ value: true })
    expect(mockPatients.size).toBe(1)
    
    const patientKey = JSON.stringify({ patientId })
    const patient = mockPatients.get(patientKey)
    
    expect(patient).toEqual({
      demographicHash,
      diagnosisHash,
      consentStatus: true,
      createdAt: mockBlockHeight,
      updatedAt: mockBlockHeight,
    })
    
    // Check that access was granted
    const accessKey = JSON.stringify({ patientId, accessor: "tx-sender" })
    expect(mockDataAccessPermissions.has(accessKey)).toBe(true)
  })
  
  it("should not register a patient that already exists", () => {
    const patientId = "patient123"
    const demographicHash = "demo-hash"
    const diagnosisHash = "diagnosis-hash"
    
    // Register once
    mockContractFunctions.registerPatient(patientId, demographicHash, diagnosisHash)
    
    // Try to register again
    const result = mockContractFunctions.registerPatient(patientId, "new-demo", "new-diagnosis")
    
    expect(result).toEqual({ error: "ERR_PATIENT_EXISTS" })
    expect(mockPatients.size).toBe(1)
  })
  
  it("should update patient data when authorized", () => {
    const patientId = "patient123"
    const demographicHash = "demo-hash"
    const diagnosisHash = "diagnosis-hash"
    
    // Register patient
    mockContractFunctions.registerPatient(patientId, demographicHash, diagnosisHash)
    
    // Update block height to simulate time passing
    mockBlockHeight = 10
    
    // Update patient data
    const newDemoHash = "new-demo-hash"
    const newDiagnosisHash = "new-diagnosis-hash"
    const result = mockContractFunctions.updatePatientData(patientId, newDemoHash, newDiagnosisHash)
    
    expect(result).toEqual({ value: true })
    
    const patientKey = JSON.stringify({ patientId })
    const patient = mockPatients.get(patientKey)
    
    expect(patient).toEqual({
      demographicHash: newDemoHash,
      diagnosisHash: newDiagnosisHash,
      consentStatus: true,
      createdAt: 1, // Original creation time
      updatedAt: 10, // New update time
    })
  })
  
  it("should not update patient data without authorization", () => {
    const patientId = "patient123"
    const demographicHash = "demo-hash"
    const diagnosisHash = "diagnosis-hash"
    
    // Register patient
    mockContractFunctions.registerPatient(patientId, demographicHash, diagnosisHash)
    
    // Remove update permission
    const accessKey = JSON.stringify({ patientId, accessor: "tx-sender" })
    mockDataAccessPermissions.set(accessKey, {
      canRead: true,
      canUpdate: false,
      expiration: 0,
    })
    
    // Try to update patient data
    const result = mockContractFunctions.updatePatientData(patientId, "new-demo", "new-diagnosis")
    
    expect(result).toEqual({ error: "ERR_UNAUTHORIZED" })
    
    // Verify data wasn't changed
    const patientKey = JSON.stringify({ patientId })
    const patient = mockPatients.get(patientKey)
    
    expect(patient.demographicHash).toBe(demographicHash)
    expect(patient.diagnosisHash).toBe(diagnosisHash)
  })
  
  it("should grant access to a third party", () => {
    const patientId = "patient123"
    const demographicHash = "demo-hash"
    const diagnosisHash = "diagnosis-hash"
    const thirdParty = "researcher1"
    
    // Register patient
    mockContractFunctions.registerPatient(patientId, demographicHash, diagnosisHash)
    
    // Grant access to third party
    const result = mockContractFunctions.grantAccess(patientId, thirdParty, true, false, 100)
    
    expect(result).toEqual({ value: true })
    
    // Verify access was granted
    const accessKey = JSON.stringify({ patientId, accessor: thirdParty })
    expect(mockDataAccessPermissions.has(accessKey)).toBe(true)
    
    const access = mockDataAccessPermissions.get(accessKey)
    expect(access).toEqual({
      canRead: true,
      canUpdate: false,
      expiration: 100,
    })
  })
  
  it("should retrieve patient data when authorized", () => {
    const patientId = "patient123"
    const demographicHash = "demo-hash"
    const diagnosisHash = "diagnosis-hash"
    
    // Register patient
    mockContractFunctions.registerPatient(patientId, demographicHash, diagnosisHash)
    
    // Get patient data
    const result = mockContractFunctions.getPatientData(patientId)
    
    expect(result).toEqual({
      value: {
        demographicHash,
        diagnosisHash,
        consentStatus: true,
        createdAt: mockBlockHeight,
        updatedAt: mockBlockHeight,
      },
    })
  })
})

