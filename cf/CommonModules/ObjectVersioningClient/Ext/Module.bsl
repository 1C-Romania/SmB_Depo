////////////////////////////////////////////////////////////////////////////////
// Subsystem "Versioning of objects".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Open a report on the object versions in versions compare mode.
//
// Parameters:
//  Refs                    - AnyRef - ref to the versioning object;
//  SerializedObjectAddress - String - the address of the binary data of the object's
//                                     compared version in a temporary storage.
//
Procedure OpenReportByChanges(Refs, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Refs);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ReportOnObjectVersions", Parameters);
	
EndProcedure

// Function opens the report on object version passed in the SerializedObjectAddress parameter.
//
// Parameters:
//  Refs                    - AnyRef - ref to the versioning object;
//  SerializedObjectAddress - String - the address of the binary data of the object version in a temporary storage.
//
Procedure OpenReportByObjectVersioning(Refs, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Refs);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	Parameters.Insert("ByVersion", True);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ReportOnObjectVersions", Parameters);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into this subsystem.

// Open a report about the version or about the versions comparison.
//
// Parameters:
// Refs - ref to the object
// ComparedVersions - Array - Contains the array of the compared versions,
// if there is one version, then it opens the report on version.
//
Procedure OnReportFormByVersionOpen(Refs, ComparedVersions) Export
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Refs);
	ReportParameters.Insert("ComparedVersions", ComparedVersions);
	OpenForm("InformationRegister.ObjectsVersions.Form.ReportOnObjectVersions", ReportParameters);
	
EndProcedure

#EndRegion
