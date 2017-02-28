////////////////////////////////////////////////////////////////////////////////
// Versioning of interfaces.
//

// Returns the array of version number names supported by the InterfaceName subsystem.
//
// Parameters:
// InterfaceName - String - Subsystem name.
//
// Returns:
// String array.
//
// Useful example:
//
// 	// Returns object WSProxy transfer files specified version.
// 	 If TransferVersion = Undefined, returns Proxy basic version "1.0.1.1".
// 
// Function GetProxyFileTransfer(Val ConnectionParameters, Val TransferVersion
// 	 = Undefined) …………………………………………………
// EndFunction
//
// Function GetFromStorage(Val FileID, Val ConnectionParameters) Export
//
// 	// Common functionality for all versions.
// 	 …………………………………………………
//
// 	// Consider versioning.
// 	SupportedVersionArray
// 		= StandardSubsystemsServer.GetSubsystemVersionArray(ConnectionParameters, "FileTransferService");
// 	If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
// 		HasVersion2Support = False;
// 		Proxy = GetProxyFileTransfer(ConnectionParameters);
// 	Else
// 		ThereIsVersion2Support = True;
// 		Proxy = GetProxyFileTransfer(ConnectionParameters, "1.0.2.1");
// 	EndIf;
//
// 	PartCount = Undefined;
// 	PartSize = 20
// 	* 1024; Kb//
//    		If ThereIsVersion2Support Then TransferID = Proxy.PrepareGetFile(FileID, PartSize, PartCount);
// 	Else
// 		TransferID = Undefined;
// 		Proxy.PrepareGetFile(FileID, PartSize, TransferID, PartCount);
// 	EndIf;
//
// 	// Common functionality for all versions.
// 	 …………………………………………………	
//
// EndFunction
//
Function GetVersions(InterfaceName)
	
	VersionArray = Undefined;
	
	SupportedVersionStructure = New Structure;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnDefenitionSupportedVersionsOfSoftwareInterfaces");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDefenitionSupportedVersionsOfSoftwareInterfaces(SupportedVersionStructure);
	EndDo;
	
	CommonUseOverridable.OnDefenitionSupportedVersionsOfSoftwareInterfaces(SupportedVersionStructure);
	
	SupportedVersionStructure.Property(InterfaceName, VersionArray);
	
	If VersionArray = Undefined Then
		Return XDTOSerializer.WriteXDTO(New Array);
	Else
		Return XDTOSerializer.WriteXDTO(VersionArray);
	EndIf;
	
EndFunction
