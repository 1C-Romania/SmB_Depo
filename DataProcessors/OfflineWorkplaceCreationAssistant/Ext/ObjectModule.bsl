#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Creates the initial image for the offline working
// place according to the passed settings and places it to the temporary storage.
// 
// Parameters:
// Settings - Structure - Settings of filters on node
// InitialImageTemporaryStorageAddress - String
// InformationAboutSettingPackageTemporaryStorageAddress - String
// 
Procedure CreateOfflineWorkplaceInitialImage(
						Val Settings,
						Val SelectedUsersSynchronization,
						Val InitialImageTemporaryStorageAddress,
						Val InformationAboutSettingPackageTemporaryStorageAddress
	) Export
	
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	// Check the content of exchange plan.
	StandardSubsystemsServer.ValidateExchangePlanContent(OfflineWorkService.OfflineWorkExchangePlan());
	
	BeginTransaction();
	Try
		
		// Assign synchronization rights to the selected users
		If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			
			CommonModuleAccessControlService = CommonUse.CommonModule("AccessManagementService");
			
			For Each User IN SelectedUsersSynchronization Do
				
				CommonModuleAccessControlService.EnableUserIntoAccessGroup(User,
					DataExchangeServer.ProfileSyncAccessDataWithOtherApplications());
			EndDo;
			
		EndIf;
		
		// Generate a prefix for new offline working place
		Block = New DataLock;
		LockItem = Block.Add("Constant.LastOfflineWorkplacePrefix");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		LastPrefix = Constants.LastOfflineWorkplacePrefix.Get();
		OfflineWorkplacePrefix = OfflineWorkService.GenerateOfflineWorkplacePrefix(LastPrefix);
		
		Constants.LastOfflineWorkplacePrefix.Set(OfflineWorkplacePrefix);
		
		// Create a node of the offline working place
		OfflineWorkplace = CreateNewOfflineWorkplace(Settings);
		
		DateOfInitialImage = CurrentSessionDate();
		
		// Export the setting parameters into the offline working place initial image
		ExportParametersIntoInitialImage(OfflineWorkplacePrefix, DateOfInitialImage, OfflineWorkplace);
		
		// Set the initial image creation date as the date of the first successful data synchronization.
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", OfflineWorkplace);
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsAtExchange.DataExport);
		RecordStructure.Insert("EndDate", DateOfInitialImage);
		InformationRegisters.SuccessfulDataExchangeStatus.AddRecord(RecordStructure);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", OfflineWorkplace);
		RecordStructure.Insert("ActionOnExchange", Enums.ActionsAtExchange.DataImport);
		RecordStructure.Insert("EndDate", DateOfInitialImage);
		InformationRegisters.SuccessfulDataExchangeStatus.AddRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogMonitorEvent(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	InitialImageDirectory = CommonUseClientServer.GetFullFileName(
		TempFilesDir(),
		InitialImageTemporaryDirectoryName());
	
	SetupDirectory = CommonUseClientServer.GetFullFileName(
		InitialImageDirectory,
		"1");
	
	DirectoryFile = CommonUseClientServer.GetFullFileName(
		SetupDirectory,
		"Infobase");
	
	InitialImageDataFileName = CommonUseClientServer.GetFullFileName(
		DirectoryFile,
		"data.xml");
	
	CreateDirectory(DirectoryFile);
	
	// Create an initial image of the offline working place
	ConnectionString = "File = &InfobaseDirectory";
	ConnectionString = StrReplace(ConnectionString, "&InfobaseDirectory", TrimAll(InitialImageDirectory));
	
	ExportedData = New XMLWriter;
	ExportedData.OpenFile(InitialImageDataFileName);
	ExportedData.WriteXMLDeclaration();
	ExportedData.WriteStartElement("Data");
	ExportedData.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
	ExportedData.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	ExportedData.WriteNamespaceMapping("v8", "http://v8.1c.ru/data");
	
	OfflineWorkplaceObject = OfflineWorkplace.GetObject();
	OfflineWorkplaceObject.AdditionalProperties.Insert("ExportedData", ExportedData);
	OfflineWorkplaceObject.AdditionalProperties.Insert("PlaceFilesIntoInitialImage");
	
	// Update the reused values of objects registration Mechanism.
	DataExchangeServerCall.CheckObjectRegistrationMechanismCache();
	
	Try
		ExchangePlans.CreateInitialImage(OfflineWorkplaceObject, ConnectionString);
	Except
		WriteLogEvent(EventLogMonitorEvent(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		
		// Store settings for offline working place in the IB is unsafe.
		Constants.SubordinatedDIBNodeSetup.Set("");
		ExportedData = Undefined;
		
		Try
			DeleteFiles(InitialImageDirectory);
		Except
			WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		// Delete offline working place
		OfflineWorkService.DeleteOfflineWorkplace(New Structure("OfflineWorkplace", OfflineWorkplace), "");
		
		Raise;
	EndTry;
	
	ExportedData.WriteEndElement(); // Data
	ExportedData.Close();
	
	InitialImageFileName = CommonUseClientServer.GetFullFileName(
		InitialImageDirectory, "1Cv8.1CD");
	
	InitialImageFileNameInArchiveDirectory = CommonUseClientServer.GetFullFileName(
		DirectoryFile, "1Cv8.1CD");
	
	SetupPackageFileName = CommonUseClientServer.GetFullFileName(
		InitialImageDirectory, OfflineWorkService.SetupPackageFileName());
	
	InstructionFileName = CommonUseClientServer.GetFullFileName(
		DirectoryFile, "ReadMe.html");
	
	InstructionText = OfflineWorkService.InstructionTextFromTemplate("InstructionForSettingOfflineWorkplace");
	
	Text = New TextWriter(InstructionFileName);
	Text.Write(InstructionText);
	Text.Close();
	
	MoveFile(InitialImageFileName, InitialImageFileNameInArchiveDirectory);
	
	Archiver = New ZipFileWriter(SetupPackageFileName,,,, ZIPCompressionLevel.Maximum);
	Archiver.Add(CommonUseClientServer.GetFullFileName(SetupDirectory, "*.*"),
			ZIPStorePathMode.StoreRelativePath,
			ZIPSubDirProcessingMode.ProcessRecursively);
	Archiver.Write();
	
	SetupPackageData = New BinaryData(SetupPackageFileName);
	
	SetupPackageFileSize = Round(SetupPackageData.Size() / 1024 / 1024, 1); // package size in Mb, for example 155.2 Mb
	
	InformationAboutSetupPackage = New Structure;
	InformationAboutSetupPackage.Insert("SetupPackageFileSize", SetupPackageFileSize);
	
	PutToTempStorage(SetupPackageData, InitialImageTemporaryStorageAddress);
	
	PutToTempStorage(InformationAboutSetupPackage, InformationAboutSettingPackageTemporaryStorageAddress);
	
	Try
		DeleteFiles(InitialImageDirectory);
	Except
		WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	// Store settings for offline working place in the IB is unsafe.
	Constants.SubordinatedDIBNodeSetup.Set("");
	
EndProcedure

//

Procedure ExportParametersIntoInitialImage(OfflineWorkplacePrefix, DateOfInitialImage, OfflineWorkplace)
	
	Constants.SubordinatedDIBNodeSetup.Set(ExportInXMLString(OfflineWorkplacePrefix, DateOfInitialImage, OfflineWorkplace));
	
EndProcedure

Function CreateNewOfflineWorkplace(Settings)
	
	// Update the application node in the service if necessary
	If IsBlankString(CommonUse.ObjectAttributeValue(OfflineWorkService.ApplicationInService(), "Code")) Then
		
		ApplicationInServiceObject = CreateApplicationInService();
		ApplicationInServiceObject.DataExchange.Load = True;
		ApplicationInServiceObject.Write();
		
	EndIf;
	
	// Create a node of the offline working place
	OfflineWorkplaceObject = CreateOfflineWorkplace();
	OfflineWorkplaceObject.Description = OfflineWorkplaceDescription;
	OfflineWorkplaceObject.RegisterChanges = True;
	OfflineWorkplaceObject.DataExchange.Load = True;
	
	// Set filters values on the node
	DataExchangeEvents.SetValuesOfFiltersAtNode(OfflineWorkplaceObject, Settings);
	
	OfflineWorkplaceObject.Write();
	
	Return OfflineWorkplaceObject.Ref;
EndFunction

Function ExportInXMLString(OfflineWorkplacePrefix, Val DateOfInitialImage, OfflineWorkplace)
	
	OfflineWorkplaceParameters = CommonUse.ObjectAttributesValues(OfflineWorkplace, "Code, description");
	ApplicationInServiceParameters = CommonUse.ObjectAttributesValues(OfflineWorkService.ApplicationInService(), "Code, description");
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	XMLWriter.WriteStartElement("Parameters");
	XMLWriter.WriteAttribute("FormatVersion", ExchangeDataSettingsFileFormatVersion());
	
	XMLWriter.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	XMLWriter.WriteNamespaceMapping("v8", "http://v8.1c.ru/data");
	
	XMLWriter.WriteStartElement("OfflineWorkplaceParameters");
	
	WriteXML(XMLWriter, DateOfInitialImage,    "DateOfInitialImage", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, OfflineWorkplacePrefix, "Prefix", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, SystemTitle(),              "SystemTitle", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, WSURLWebService,                 "URL", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, InfobaseUsers.CurrentUser().Name, "OwnerName", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, String(Users.AuthorizedUser().UUID()), "Owner", XMLTypeAssignment.Explicit);
	
	WriteXML(XMLWriter, OfflineWorkplaceParameters.Code,          "CodeOfOfflineWorkplace", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, OfflineWorkplaceParameters.Description, "OfflineWorkplaceDescription", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, ApplicationInServiceParameters.Code,                "ApplicationInServiceCode", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, ApplicationInServiceParameters.Description,       "ApplicationNameInService", XMLTypeAssignment.Explicit);
	
	XMLWriter.WriteEndElement(); // OfflineWorkplaceParameters
	XMLWriter.WriteEndElement(); // Parameters
	
	Return XMLWriter.Close();
EndFunction

Function ExchangeDataSettingsFileFormatVersion()
	
	Return "1.0";
	
EndFunction

Function EventLogMonitorEvent()
	
	Return OfflineWorkService.EventLogMonitorEventCreatingOfflineWorkplace();
	
EndFunction

Function InitialImageTemporaryDirectoryName()
	
	Return StrReplace("Replica {GUID}", "GUID", String(New UUID));
	
EndFunction

Function CreateApplicationInService()
	
	Result = ExchangePlans[OfflineWorkService.OfflineWorkExchangePlan()].ThisNode().GetObject();
	Result.Code = String(New UUID);
	Result.Description = GenerateApplicationNameInService();
	
	Return Result;
EndFunction

Function CreateOfflineWorkplace()
	
	Result = ExchangePlans[OfflineWorkService.OfflineWorkExchangePlan()].CreateNode();
	Result.Code = String(New UUID);
	
	Return Result;
EndFunction

Function GenerateApplicationNameInService()
	
	ApplicationName = DataExchangeSaaS.GeneratePredefinedNodeDescription();
	
	Result = "[ApplicationName] ([Explanation])";
	Result = StrReplace(Result, "[ApplicationName]", ApplicationName);
	Result = StrReplace(Result, "[Explanation]", NStr("en = 'Application in Internet'"));
	
	Return Result;
EndFunction

Function SystemTitle()
	
	Result = "";
	
	Parameters = New Structure;
	StandardSubsystemsServer.AddClientWorkParameters(Parameters);
	
	Result = Parameters.ApplicationCaption;
	
	If IsBlankString(Result) Then
		
		If Parameters.Property("DataAreaPresentation") Then
			
			Result = Parameters.DataAreaPresentation;
			
		EndIf;
		
	EndIf;
	
	Return ?(IsBlankString(Result), NStr("en = 'Offline working place'"), Result);
EndFunction

#EndIf
