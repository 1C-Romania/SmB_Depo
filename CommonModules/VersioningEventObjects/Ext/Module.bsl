////////////////////////////////////////////////////////////////////////////////
// Subsystem "Versioning of objects".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Writes the object's version (except documents) into the infobase.
//
// Parameters:
//  Source - Object  - IB object being written;
//  Cancel - Boolean - flag showing the cancelation of object writing.
//
Procedure WriteObjectVersion(Source, Cancel) Export
	
	ObjectVersioning.WriteObjectVersion(Source, False);
	
EndProcedure

// Writes the document's version into the infobase.
//
// Parameters:
//  Source    - Object  - IB document being written;
//  Cancel    - Boolean - flag showing the cancelation of document writing.
//
Procedure WriteDocumentVersion(Source, Cancel, WriteMode, PostingMode) Export
	
	ObjectVersioning.WriteObjectVersion(Source, WriteMode <> DocumentWriteMode.Write);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into this subsystem.

// Writes the object's version into the infobase. It is
// called when exchanging data with another infobase.
//
// Parameters:
//  Source - Object - IB object being written;
//  Cancel    - Boolean - flag showing the cancelation of object writing.
//
Procedure WriteObjectVersionOnDataExchange(Source, Cancel) Export
	
	If Source.AdditionalProperties.Property("InfoAboutObjectVersion") Then
		
		ObjectVersioning.OnCreateObjectVersionByDataExchange(Source);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// Only for internal use.
//
Procedure DeleteInformationAboutAuthorVersion(Source, Cancel) Export
	
	InformationRegisters.ObjectsVersions.DeleteInformationAboutAuthorVersion(Source.Ref);
	
EndProcedure

#EndRegion
