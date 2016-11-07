#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// FILLING PROCEDURES

Procedure PrepareDataForFillingDocuments(RefsToObjectArray, StorageAddress) Export
	
	TableED = New ValueTable;
	TableED.Columns.Add("FullFileName");
	TableED.Columns.Add("FileDescription");
	TableED.Columns.Add("EDDirection");
	TableED.Columns.Add("Counterparty");
	TableED.Columns.Add("UUID");
	TableED.Columns.Add("EDOwner");
	TableED.Columns.Add("StorageAddress");
	TableED.Columns.Add("BinaryDataPackage");
	TableED.Columns.Add("AdditFileFullName");
	TableED.Columns.Add("AdditFileIdentifier");
	
	ObjectsSettings = New Map;
	For Each ObjectReference IN RefsToObjectArray Do
		ExchangeSettings = ElectronicDocumentsService.FillEDParametersBySource(ObjectReference);
		
		ExchangeSettings.Insert("CompanyID", ElectronicDocumentsOverridable.GetCounterpartyId(
		ExchangeSettings.Company, "Company"));
		ExchangeSettings.Insert("CounterpartyID", ElectronicDocumentsOverridable.GetCounterpartyId(
		ExchangeSettings.Counterparty, "Counterparty"));
		
		ExchangeSettings.Insert("EDFProfileSettings", New Structure("EDExchangeMethod", Enums.EDExchangeMethods.QuickExchange));
		ExchangeSettings.Insert("EDAgreement", "");
		ExchangeSettings.Insert("FormatVersion", ElectronicDocumentsReUse.CML2SchemeVersion());
		
		ObjectsSettings.Insert(ObjectReference, ExchangeSettings);
		If ExchangeSettings.EDKind = Enums.EDKinds.ActPerformer
			OR ExchangeSettings.EDKind = Enums.EDKinds.ActCustomer Then
			ExchangeSettings.Insert("EDFScheduleVersion", Enums.Exchange1CRegulationsVersion.Version10);
		EndIf;
	EndDo;
	
	ExchangeStructuresArray = ElectronicDocumentsService.GenerateDocumentsXMLFiles(RefsToObjectArray,
		ObjectsSettings);
		
	For Each ExchangeStructure IN ExchangeStructuresArray Do
		FullFileName = ElectronicDocumentsService.GetEDFileFullName(ExchangeStructure);
		If Not ValueIsFilled(FullFileName) Then
			Continue;
		EndIf;
		
		NewRow = TableED.Add();
		NewRow.FullFileName = FullFileName;
		ExchangeStructure.Property("AdditFileFullName", NewRow.AdditFileFullName);
		ExchangeStructure.Property("AdditFileIdentifier", NewRow.AdditFileIdentifier);
		
		FileDescription = QuickExchangeNameSavedFile(ExchangeStructure.EDStructure.EDOwner);
		NewRow.FileDescription = FileDescription;
		NewRow.EDDirection = ExchangeStructure.EDStructure.EDDirection;
		NewRow.Counterparty = ExchangeStructure.EDStructure.Counterparty;
		NewRow.UUID = ExchangeStructure.EDStructure.EDOwner.UUID();
		NewRow.EDOwner = ExchangeStructure.EDStructure.EDOwner;
		
		NewRow.BinaryDataPackage = GenerateEDTakskomPackageAttachedFile(ExchangeStructure);
		
	EndDo;
	
	If ValueIsFilled(TableED) Then
		PutToTempStorage(TableED, StorageAddress);
	Else
		StorageAddress = Undefined;
		
		Raise  NStr("en = 'An error occurred when forming the single transaction package." + Chars.LF
								+" Details see Event Log Monitor'");

	EndIf;
	
EndProcedure

// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

Function GenerateEDTakskomPackageAttachedFile(ExchangeStructure) Export
	
	ExchangeStructure.EDStructure.Insert("EDFProfileSettings", New Structure("EDExchangeMethod",
		Enums.EDExchangeMethods.QuickExchange));
	
	ErrorText = "";
	StorageAddress = Undefined;
	
	DirectoryAddress = ElectronicDocumentsService.WorkingDirectory("Send");
	If ExchangeStructure.EDKind = Enums.EDKinds.ProductsDirectory Then
		FileDescription = ExchangeStructure.Description;
	Else
		FileDescription = QuickExchangeNameSavedFile(ExchangeStructure.EDStructure.EDOwner);
	EndIf;
	
	PDFFileName = ElectronicDocumentsService.GenerateAdditDocument(ExchangeStructure, Enums.EDExchangeFileFormats.PDF);
	FileCopy(PDFFileName, DirectoryAddress + FileDescription + ".pdf");

	
	FileCopy(ExchangeStructure.FullFileName, DirectoryAddress + FileDescription + ".xml");
	
	StructureFilesED = New Structure;
	StructureFilesED.Insert("MainFile", FileDescription + ".xml");
	StructureFilesED.Insert("FileForViewing", FileDescription + ".pdf");
	
	PathToAddFile = "";
	If ExchangeStructure.Property("AdditFileFullName", PathToAddFile) AND ValueIsFilled(PathToAddFile) Then
		NameAddFile = String(ExchangeStructure.AdditFileIdentifier);
		FileCopy(PathToAddFile, DirectoryAddress + NameAddFile + ".xml");
		StructureFilesED.Insert("AdditionalFile", NameAddFile + ".xml");
	EndIf;
	
	If ExchangeStructure.Property("Images") AND ValueIsFilled(ExchangeStructure.Images) Then
		PathToAddFile = GetTempFileName();
		FileBinaryData = GetFromTempStorage(ExchangeStructure.Images);
		FileBinaryData.Write(PathToAddFile);
		FileCopy(PathToAddFile, DirectoryAddress + "Additional files" + ".zip");
		StructureFilesED.Insert("AdditionalFile", "Additional files" + ".zip");
		DeleteFiles(PathToAddFile);
	EndIf;
	
	// Form meta.xml.
	ElectronicDocumentsInternal.GenerateEDTransportInformationTakskom(ExchangeStructure.EDStructure,
	StructureFilesED, DirectoryAddress, ErrorText);
	
	// Form card.xml.
	ElectronicDocumentsInternal.GenerateEDCardTakskom(ExchangeStructure.EDStructure, DirectoryAddress, ErrorText);
	
	If Not ValueIsFilled(ErrorText) Then
		
		ZipContainer = New ZipFileWriter();
		ArchiveFileName = ElectronicDocumentsService.TemporaryFileCurrentName("zip");

		ZipContainer.Open(ArchiveFileName);
		
		AddingObjectsInArchive = DirectoryAddress + "*";
		ZipContainer.Add(AddingObjectsInArchive, ZIPStorePathMode.StoreRelativePath,
		ZIPSubDirProcessingMode.ProcessRecursively);
		
		Try
			ZipContainer.Write();
			BinaryDataPackage = New BinaryData(ArchiveFileName);
		Except
			MessagePattern = NStr("en='%1 (see details in event log monitor).';ru='%1 (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				?(ValueIsFilled(ErrorText), ErrorText, BriefErrorDescription(ErrorInfo())));
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
				NStr("en='ED package generation - non-recurring transaction';ru='Формирование пакета ЭД - однократная сделка'"), DetailErrorDescription(ErrorInfo()),
				MessageText);
		EndTry;
		DeleteFiles(ArchiveFileName);
	Else
		MessagePattern = NStr("en='During the generation %1 the
		|following  errors occurred: %2';ru='При формировании %1 возникли следующие ошибки: %2'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ExchangeStructure.EDKind,
			ErrorText);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	DeleteFiles(DirectoryAddress);
	Return BinaryDataPackage;
	
EndFunction

Function QuickExchangeNameSavedFile(EDOwner)
	
	FileDescription = "";
	ElectronicDocumentsOverridable.AssignSavedFileNameOnQuickExchange(EDOwner, FileDescription);
	If ValueIsFilled(EDOwner) AND Not ValueIsFilled(FileDescription) Then
		
		If TypeOf(EDOwner) = Type("CatalogRef.Companies") Then
			
			AttributesStructure = CommonUse.ObjectAttributesValues(EDOwner, "Description");
			FileTemplate = NStr("en='%1';ru='%1'");
			FileDescription = StringFunctionsClientServer.PlaceParametersIntoString(FileTemplate, AttributesStructure.Description);
			
		Else
			
			AttributesStructure = CommonUse.ObjectAttributesValues(EDOwner, "Number, Date");		
			FileTemplate = NStr("en='%1 # %2 date %3';ru='%1 № %2 от %3'");
			FileDescription = StringFunctionsClientServer.PlaceParametersIntoString(FileTemplate, String(TypeOf(EDOwner)),
															AttributesStructure.Number, Format(AttributesStructure.Date, "DLF=D"));
		EndIf;
		
		FileDescription = CommonUseClientServer.ReplaceProhibitedCharsInFileName(FileDescription);
		
	EndIf;
	
	Return FileDescription;
	
EndFunction

#EndIf