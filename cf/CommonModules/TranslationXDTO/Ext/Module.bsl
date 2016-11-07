////////////////////////////////////////////////////////////////////////////////
// Subsystem "XDTO translation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Function translates an arbitrary XDTO object
// between versions by translation handlers registered
// in the system, determining the resulting version by the resulting message namespace.
//
// Parameters:
//  InitialObject - XDTODataObject, object being translated, 
//  ResultingVersion - String, interface resulting version number, in PP format.{P|PP}.ZZ.SS.
//
// Returns:
//  XDTODataObject - result of translating the object.
//
Function TransferToVersion(Val InitialObject, Val ResultingVersion, Val SourceVersionPackage = "") Export
	
	If SourceVersionPackage = "" Then
		SourceVersionPackage = InitialObject.Type().NamespaceURI;
	EndIf;
	
	InitialVersionsDetails = TranslationXDTOService.GenerateVersionDescription(
		,
		SourceVersionPackage);
	DetailsOfResultingVersions = TranslationXDTOService.GenerateVersionDescription(
		ResultingVersion);
	
	Return TranslationXDTOService.ExecuteBroadcast(
		InitialObject,
		InitialVersionsDetails,
		DetailsOfResultingVersions);
	
EndFunction

// Function translates an arbitrary
// XDTO object between versions by translation handlers registered
// in the system, determining the resulting version by the resulting message namespace.
//
// Parameters:
//  InitialObject - XDTODataObject,
//  object being translated, ResultingVersion - String, resulting version namespace,
//
// Returns:
//  XDTODataObject - result of translating the object.
//
Function TransmitInToNamespace(Val InitialObject, Val PackageResultingVersions, Val SourceVersionPackage = "") Export
	
	If InitialObject.Type().NamespaceURI = PackageResultingVersions Then
		Return InitialObject;
	EndIf;
	
	If SourceVersionPackage = "" Then
		SourceVersionPackage = InitialObject.Type().NamespaceURI;
	EndIf;
	
	InitialVersionsDetails = TranslationXDTOService.GenerateVersionDescription(
		,
		SourceVersionPackage);
	DetailsOfResultingVersions = TranslationXDTOService.GenerateVersionDescription(
		,
		PackageResultingVersions);
	
	Return TranslationXDTOService.ExecuteBroadcast(
		InitialObject,
		InitialVersionsDetails,
		DetailsOfResultingVersions);
	
EndFunction

#EndRegion
