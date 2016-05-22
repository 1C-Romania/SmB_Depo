////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Subsystem "Address Classifier" in service model.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ServerHandlers["StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
			"AddressClassifierSaaSService");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
			"AddressClassifierSaaSService");
	EndIf;
	
EndProcedure

// Register the handlers of supplied data for the day and for all time.
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "FIAS";
	Handler.ProcessorCode = "FIAS";
	Handler.Handler = AddressClassifierSaaSService;
	
EndProcedure

// It is called when a notification of new data received.
// In the body you should check whether this data is necessary for the application, and if so, - select the Import check box.
// 
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   Import    - Boolean, return.
//
Procedure AvailableNewData(Val Handle, Import) Export
	
	If Handle.DataType = "FIAS" Then
		
		Import = CheckNewDataExistence(Handle);
		
	EndIf;
	
EndProcedure

// It is called after the call AvailableNewData, allows you to parse data.
//
// Parameters:
//   Handle   - XDTOObject Descriptor.
//   PathToFile   - String or Undefined. The full name of the extracted file. File will be automatically
// deleted after procedure completed. If the file was not
//                  specified in the service manager - The argument value is Undefined.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	If Handle.DataType = "FIAS" Then
		ProcessFIAS(Handle, PathToFile);
	EndIf;
	
EndProcedure

// It is called on a data processing cancel in case of failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function FIASParameters()
	
	Return New Structure("Version, State");
	
EndFunction

Function FileVersionParameters(Val Handle)
	
	VersionParameters =  FIASParameters();
	
	For Each Characteristic In Handle.Properties.Property Do
		If Characteristic.Code = "State" Then
			VersionParameters.State = StringFunctionsClientServer.StringToNumber(Characteristic.Value);
		ElsIf Characteristic.Code = "Version" Then
			VersionParameters.Version = StringFunctionsClientServer.StringToNumber(Characteristic.Value);
		EndIf;
	EndDo;
	
	Return VersionParameters;
	
EndFunction

Function FIASLastImportDescription(Val StateCode)
	
	Result = FIASParameters();
	Query = New Query();
	
	Query.SetParameter("RFTerritorialEntityCode", StateCode);
	Query.Text = 
		"SELECT
		|	AddressInformationExportedVersions.Version,
		|	AddressInformationExportedVersions.RFTerritorialEntityCode AS State
		|FROM
		|	InformationRegister.AddressInformationExportedVersions AS AddressInformationExportedVersions
		|WHERE
		|	AddressInformationExportedVersions.RFTerritorialEntityCode = &RFTerritorialEntityCode";
		
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result.Version = StringFunctionsClientServer.StringToNumber(Selection.Version);
		Result.State = Selection.State;
	EndIf;
	
	Return Result;
	
EndFunction

Function CheckNewDataExistence(Val Handle)
	
	NewDataParameters = FileVersionParameters(Handle);
	If NewDataParameters.Version = Undefined Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(NewDataParameters.State) Then
		Return True;
	EndIf;
	
	CurrentDataParameters = FIASLastImportDescription(NewDataParameters.State);
	If CurrentDataParameters.Version = Undefined 
		OR NewDataParameters.Version > CurrentDataParameters.Version Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Procedure ProcessFIAS(Val Handle, Val PathToFile)
	
	FileDirectory = CommonUseClientServer.AddFinalPathSeparator(GetTempFileName());
	
	Try
		ZIPReader = New ZipFileReader(PathToFile);
		ZIPReader.ExtractAll(FileDirectory, ZIPRestoreFilePathsMode.DontRestore);
		ZIPReader.Close();
		
		// Import only what transferred in files.
		RFTerritorialEntities = New Array;
		NumberType   = New TypeDescription("Number");
		FilesDescription = New Array;
		
		For Each File In FindFiles(FileDirectory, "??.ZIP") Do
			StateCode = NumberType.AdjustValue(Left(File.Name, 2));
			If StateCode > 0 Then
				RFTerritorialEntities.Add(StateCode);
			EndIf;
			FilesDescription.Add( New Structure("Name, Storage", File.FullName, File.FullName));
		EndDo;
		
		If RFTerritorialEntities.Count() > 0 Then
			AddressClassifierService.ImportAddressClassifier(RFTerritorialEntities, FilesDescription, False);
		EndIf;
		
	Except
		AddressClassifierService.DeleteTemporaryFile(FileDirectory);
		Raise;
	EndTry;
	
EndProcedure

// Event handlers of the SSL subsystems.

// Register the handlers of supplied data.
//
// When getting notification of new common data accessibility the procedure is called.
// AvailableNewData modules registered through GetSuppliedDataHandlers.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// In case if AvailableNewData sets the argument to Import in value is true, the data is importing, the handle and the path to the file with data pass to a procedure.
// ProcessNewData. File will be automatically deleted after procedure completed.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//     Handlers - ValueTable - The table for adding handlers. Contains columns.
//       * DataKind      - String      - the code of data kind processed by the handler.
//       * ProcessorCode - String      - it will be used during restoring data processing after the failure.
//       * Handler     - CommonModule - the module that contains the export procedures:
//                                          AvailableNewData(Descriptor,
//                                          Import) Export ProcessNewData(Descriptor,
//                                          PathToFile) Export DataProcessingCanceled(Descriptor) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array - populated with metadata.
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.AddressClassifierDataSource);
	
	MetadataRegisters = Metadata.InformationRegisters;
	
	Types.Add(MetadataRegisters.AddressObjects);
	Types.Add(MetadataRegisters.HousesBuildingsConstructions);
	Types.Add(MetadataRegisters.AdditionalAddressInformation);
	Types.Add(MetadataRegisters.AddressInformationExportedVersions);
	Types.Add(MetadataRegisters.AddressObjectsHistory);
	Types.Add(MetadataRegisters.AddressObjectsLandmarks);
	Types.Add(MetadataRegisters.AddressInformationChangingReasons);
	Types.Add(MetadataRegisters.ServiceAddressData);
	Types.Add(MetadataRegisters.AddressInformationReductionsLevels);
	
	Types.Add(MetadataRegisters.DeleteAddressClassifier);
	
EndProcedure

#EndRegion
