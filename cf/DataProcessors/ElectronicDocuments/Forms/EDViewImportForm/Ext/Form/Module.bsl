
#Region CommonUseProceduresAndFunctions

&AtServerNoContext
Function CreateIBObjects(TemporaryStorageAddress, RecordingError)
	
	Var ParseTree;
	
	ParcingStructure = GetFromTempStorage(TemporaryStorageAddress);
	
	If ParcingStructure <> Undefined AND ParcingStructure.Property("ParseTree", ParseTree) Then
		// Fill in the references to the objects from the
		// matches tree if there are no references, then create objects
		ElectronicDocumentsInternal.FillRefsToObjectsInTree(ParseTree, RecordingError);
	EndIf;
	
EndFunction

&AtServerNoContext
Function SaveVBDObjectData(TemporaryStorageAddress)
	
	ParcingStructure = GetFromTempStorage(TemporaryStorageAddress);
	
	If ParcingStructure <> Undefined AND ParcingStructure.Property("ParseTree") Then
		ElectronicDocumentsOverridable.SaveVBDObjectData(
										ParcingStructure.ObjectString,
										ParcingStructure.ParseTree);
	EndIf;
	
EndFunction

&AtClient
Procedure CompareProductsAndServices(NotificationHandler)
	
	ReturnValue = Undefined;
	EDStructure = New Structure;
	EDStructure.Insert("EDKind", EDKind);
	EDStructure.Insert("EDExchangeMethod", PredefinedValue("Enum.EDExchangeMethods.QuickExchange"));
	EDStructure.Insert("Counterparty", Counterparty);
	EDStructure.Insert("ParseFileData", ParseFileData);
	EDStructure.Insert("EDDirection", PredefinedValue("Enum.EDDirections.Incoming"));
	EDStructure.Insert("FileOwner", ?( DocumentImportMethod = 0, Undefined,IBDocument));
	
	ParametersStructure = ElectronicDocumentsServiceCallServer.GetProductsAndServicesComparingFormParameters(EDStructure);
	If ValueIsFilled(ParametersStructure) Then
		
		OpenForm(ParametersStructure.FormName, ParametersStructure.FormOpenParameters,,,,, NotificationHandler);
		
	EndIf;
		
EndProcedure

&AtClient
Procedure ChangeVisibleEnabled()
	
	If Upper(EDKind) = Upper("CompanyAttributes") Then
		
		Items.CatalogItemIB.Enabled = (DocumentImportMethod = 1);
		
	Else	
		If EDImport Then
			Items.IBDocument.Enabled = (DocumentImportMethod = 1);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeVisibleOfEnabledWhenCreatingServer()
	
	Items.DocumentContentGroup.PagesRepresentation = FormPagesRepresentation.None;
	
	If EDImport Then
		
		Items.ButtonGroup.Visible = True;
		Items.GroupHyperlink.Visible = False;

		If Upper(EDKind) = Upper("CompanyAttributes") Then
			
			Title = NStr("en='Data import from the file';ru='Загрузка данных из файла'");
			
			Items.SettingsGroupCatalogs.Visible = True;
			Items.SettingsGroupDocuments.Visible = False;
		Else
			
			Title = NStr("en='Document loading from the file';ru='Загрузка документа из файла'");
			
			Items.SettingsGroupCatalogs.Visible = False;
			Items.SettingsGroupDocuments.Visible = True;
		EndIf;
		
	Else
		Text = NStr("en='Electronic document';ru='Электронный документ'");
		Title = Text;
		Items.SettingsGroupCatalogs.Visible = False;
		Items.SettingsGroupDocuments.Visible = False;
		Items.ButtonGroup.Visible = False;
		Items.GroupHyperlink.Visible = True;
	EndIf;
	
	If EDKind = Enums.EDKinds.ProductsDirectory Then
		Items.Import.Visible = False;
		Items.ObjectType.Title = NStr("en='Import';ru='Загрузить'");
		ObjectType = "Products directory";
	EndIf;
	
EndProcedure

&AtServer
Procedure ToViewEDServer(EDStructure, Cancel)
	
	Var RefillDocument, ParseTree, ObjectString;
	
	ViewFile = Undefined;
	ImagesFileName = Undefined;
	
	BinaryData = GetFromTempStorage(EDStructure.StorageAddress);
	
	If EDStructure.FileOfArchive Then
		FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory("Ext", EDStructure.UUID);
		ArchiveFileName = ElectronicDocumentsService.TemporaryFileCurrentName("zip");
		BinaryData.Write(ArchiveFileName);
		
		DeleteFiles(FolderForUnpacking, "*");
		
		ZIPReading = New ZipFileReader(ArchiveFileName);
		Try
			ZIPReading.ExtractAll(FolderForUnpacking);
		Except
			ErrorText = BriefErrorDescription(ErrorInfo());
			If Not ElectronicDocumentsService.PossibleToExtractFiles(ZIPReading, FolderForUnpacking) Then
				MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
			EndIf;
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED archive unpacking';ru='Распаковка архива ЭД'"),
			ErrorText, MessageText);
			
			DeleteFiles(ArchiveFileName);
			DeleteFiles(FolderForUnpacking);
			Return;
		EndTry;
		
		DeleteFiles(ArchiveFileName);
		// copy the view file
		ViewFilesArray = FindFiles(FolderForUnpacking, "*.pdf", True);
		If ViewFilesArray.Count() > 0 Then
			ViewFile = ViewFilesArray[0];
		EndIf;
		
		// Decrypt file with data
		InformationArrayFile = FindFiles(FolderForUnpacking, "meta*.xml", True);
		If InformationArrayFile.Count() > 0 Then
			InformationFile = InformationArrayFile[0];
		EndIf;
		
		CardArrayFile = FindFiles(FolderForUnpacking, "card*.xml", True);
		If CardArrayFile.Count() > 0 Then
			CardFile = CardArrayFile[0];
		EndIf;
		
		// copy the view file
		ImagesFilesArray = FindFiles(FolderForUnpacking, "*.zip", True);
		If ImagesFilesArray.Count() > 0 Then
			PicturesFile = ImagesFilesArray[0];
			ImagesFileName = PicturesFile.FullName;
		EndIf;
		
		If CardFile = Undefined Or InformationFile = Undefined Then
			
			MessagePattern = NStr("en='Error occurred when reading data from the ""%1No."" file (see details in the event log).';ru='Возникла ошибка при чтении данных из файла ""%1№"" (подробности см. в Журнале регистрации).'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, EDStructure.FileName);
			
			MessagePattern = NStr("en='""%1"" file does not contain electronic documents.';ru='Файл ""%1"" не содержит электронных документов.'");
			ErrorPresentation = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, EDStructure.FileName);
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED reading';ru='Чтение ЭД.'"),
			ErrorPresentation,
			MessageText);
			DeleteFiles(FolderForUnpacking);
			Cancel = True;
			Return;
		EndIf;
		
		MapFileParameters = ElectronicDocumentsInternal.GetCorrespondingFileParameters(InformationFile, CardFile);
		
		For Each MapItem IN MapFileParameters Do
			
			FilesArraySource = FindFiles(FolderForUnpacking, MapItem.Key, True);
			If FilesArraySource.Count() > 0 Then
				FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
				
				
				FileNameCML = FilesArraySource[0].Name;
				FileCopy(FilesArraySource[0].FullName, FileName);
				
			EndIf;
		EndDo;
		
	Else
		FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
		BinaryData.Write(FileName);
	EndIf;

	EDStructure.Property("DocumentRef", RefillDocument);
	
	ParcingStructure = ElectronicDocumentsInternal.GenerateParseTree(FileName,
																				Enums.EDDirections.Incoming,
																				,
																				ImagesFileName);
	BinaryDataParseFile = New BinaryData(FileName);
	ParseFileData = PutToTempStorage(BinaryDataParseFile, UUID);
	
	EDData = Undefined;
	
	If TypeOf(ParcingStructure) = Type("Structure") Then
		
		AddressStructureEDParsing = PutToTempStorage(ParcingStructure, UUID);
		EDData = ElectronicDocumentsInternal.EDPrintForm(
			ParcingStructure, EDStructure.EDDirection, EDStructure.UUID, , EDKind);
	EndIf;
	
	If TypeOf(EDData) = Type("SpreadsheetDocument") Then
		
		If EDImport Then
			If (NOT ValueIsFilled(IBDocument) OR DocumentImportMethod = 0) AND ParcingStructure <> Undefined
					AND ParcingStructure.Property("ParseTree", ParseTree)
					AND ParcingStructure.Property("ObjectString", ObjectString) Then
				RecordingError = False;
				TreeRow = FindRowInTree(ParseTree, ObjectString, "Counterparty");
				If TreeRow <> Undefined Then
					Counterparty = TreeRow.ObjectReference;
				EndIf;
			EndIf;
			ElectronicDocumentsOverridable.DocumentsKindsListByEDKind(EDKind, TypeList);
			For Each CurValue IN TypeList Do
				CurItem = Items.ObjectType.ChoiceList.Add();
				CurItem.Value = CurValue.Presentation;
				
				// If the IBDocument attribute has not been filled out yet and the first value from the list is read, then fill with available data:
				If Not ValueIsFilled(IBDocument) AND TypeList.IndexOf(CurValue) = 0 Then
					ObjectType = CurValue.Presentation;
					IBDocument = CurValue.Value;
					MetadataObjectName = CurValue.Value.Metadata().FullName();
				EndIf;
				// If there is a ref (refilled) to the IB document in the parameters structure and its type matches
				// to one of the type of the types list values, then fill out the corresponding form attributes with these data.
				// This condition is required for the correct processing of the situation, when
				// the refilled document is selected as the document with the selected type that does not match either with one of the available in the list or does not match with the type of the first item of the list.
				If ValueIsFilled(RefillDocument) AND TypeOf(RefillDocument) = TypeOf(CurValue.Value) Then
					ObjectType = CurValue.Presentation;
					IBDocument = RefillDocument;
					MetadataObjectName = CurValue.Value.Metadata().FullName();
				EndIf;
			EndDo;
		EndIf;
		
		If Not ValueIsFilled(Counterparty) AND ValueIsFilled(RefillDocument) Then
			
			CatalogNameCounterparties = CatalogName("Counterparties");
			
			If Not ValueIsFilled(CatalogNameCounterparties) Then
				CatalogNameCounterparties = "Counterparties";
			EndIf;
			
			If TypeOf(RefillDocument) = Type("CatalogRef."+ CatalogNameCounterparties) Then
				Counterparty = RefillDocument;
			Else
				Counterparty = RefillDocument.Counterparty;
			EndIf;
			
		EndIf;
		
		FormTableDocument = EDData;
		Items.DocumentContentGroup.CurrentPage = Items.PageTableDocument;
		
	Else
		
		If Not ViewFile = Undefined Then
			
			
			PathToFile = ViewFile.FullName;
			FileExtension = StrReplace(ViewFile.Extension, ".", "");
			
			QQFile = New BinaryData(PathToFile);
			
			// Pass to client the binary file data for view:
			AddressStructureEDParsing = PutToTempStorage(QQFile, UUID);
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(FolderForUnpacking) Then
		DeleteFiles(FolderForUnpacking);
	EndIf;
	
EndProcedure

&AtServer
Function CatalogName(CatalogName)
	
	CatalogName = ElectronicDocumentsReUse.GetAppliedCatalogName(CatalogName);
	
	Return CatalogName;
	
EndFunction

&AtServer
Function FindRowInTree(ParseTree, ObjectString, SearchObjectName)
	
	ReturnValue = Undefined;
	
	SearchStructure = New Structure("Attribute", SearchObjectName);
	RowArray = ObjectString.Rows.FindRows(SearchStructure);
	If RowArray.Count() > 0 Then
		RowIndexOfCounterparty = RowArray[0].AttributeValue;
		SearchStructure = New Structure("RowIndex", RowIndexOfCounterparty);
		RowArray = ParseTree.Rows.FindRows(SearchStructure, True);
		If RowArray.Count() > 0 Then
			TreeRow = RowArray[0];
			ReturnValue = TreeRow;
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

&AtServer
Function CreateDocumentForIB(FormData, MessageText, Write = False)
	
	Var ObjectString, ParseTree;
	
	IBDocumentGenerated = False;
	
	If ValueIsFilled(AddressStructureEDParsing) AND IsTempStorageURL(AddressStructureEDParsing) Then
		ParcingStructure = GetFromTempStorage(AddressStructureEDParsing);
	Else
		
		FileName = GetTempFileName("xml");
		FileBinaryData = GetFromTempStorage(ParseFileData);
		FileBinaryData.Write(FileName);
		
		ParcingStructure = ElectronicDocumentsInternal.GenerateParseTree(FileName,
																					Enums.EDDirections.Incoming);
		DeleteFiles(FileName);
	EndIf;
	If ParcingStructure <> Undefined AND ParcingStructure.Property("ParseTree", ParseTree)
		AND ParcingStructure.Property("ObjectString", ObjectString) Then
		// If a counterparty is specified on the form, and it does not match the counterparty in
		// the parse tree (found by the attributes from ED), then we replace the counterparty in the tree by the counterparty from the form.
		TreeRow = FindRowInTree(ParseTree, ObjectString, "Counterparty");
		If TreeRow.ObjectReference <> Counterparty Then
			TreeRow.ObjectReference = Counterparty;
		EndIf;
		DocumentRef = ?(DocumentImportMethod = 1, IBDocument, Undefined);
		Try
			CounterpartyRef = ElectronicDocumentsOverridable.SaveVBDObjectData(ObjectString,
																							ParseTree,
																							DocumentRef,
																							Write);
																							
			If FormData <> Undefined Then
				If Write Then
					CounterpartyObject = CounterpartyRef.GetObject();
				Else
					CounterpartyObject = CounterpartyRef;
				EndIf;
				
				ValueToFormData(CounterpartyObject, FormData);
			Else
				
				If Upper(EDKind) = Upper("CompanyAttributes") Then
					
					FormData = CounterpartyRef;
					
				Else
					
					FormData = CounterpartyObject;
					
				EndIf;
			EndIf;
			
			IBDocumentGenerated = True;
			
		Except
			
			MessagePattern = NStr("en='%1. %2 ';ru='%1. %2 '");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
				ErrorInfo().Definition,
				BriefErrorDescription(ErrorInfo()));

		EndTry;
	EndIf;

	Return IBDocumentGenerated;
	
EndFunction

&AtServerNoContext
Function CanImportEDWithType(Val EDKind)
	
	CanImport = True;
	ArrayOfCurrentTypesOfED = ElectronicDocumentsReUse.GetEDActualKinds();
	If ArrayOfCurrentTypesOfED.Find(EDKind) = Undefined Then
		CanImport = False;
	EndIf;
	
	Return CanImport;
	
EndFunction

&AtServer
Function EDDataFile(LinkToED, Val SubordinatedEDFileName = Undefined)
	
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(LinkToED,
	                                                                      LinkToED.UUID(),
	                                                                      True);
	
	If AdditInformationAboutED.Property("FileBinaryDataRef")
		AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef) Then
		
		EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);
		
		If ValueIsFilled(AdditInformationAboutED.Extension) Then
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName(AdditInformationAboutED.Extension);
		Else
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
		EndIf;
		
		If FileName = Undefined Then
			ErrorText = NStr("en='Unable to view electronic document. Verify the work directory setting';ru='Не удалось просмотреть электронный документ. Проверьте настройку рабочего каталога'");
			CommonUseClientServer.MessageToUser(ErrorText);
			Return Undefined;
		EndIf;
		
		EDData.Write(FileName);
		
		If LinkToED.EDKind = Enums.EDKinds.TORG12Customer
			OR LinkToED.EDKind = Enums.EDKinds.ActCustomer
			OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
			
			SpreadsheetDocument = EDDataFile(LinkToED.ElectronicDocumentOwner, FileName);
			Return SpreadsheetDocument;
		ElsIf Find(AdditInformationAboutED.Extension, "zip") > 0 Then
			
			ZIPReading = New ZipFileReader(FileName);
			FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory(,LinkToED.UUID());
			
			If FolderForUnpacking = Undefined Then
				ErrorText = NStr("en='Unable to view electronic document. Verify the work directory setting';ru='Не удалось просмотреть электронный документ. Проверьте настройку рабочего каталога'");
				CommonUseClientServer.MessageToUser(ErrorText);
				Return Undefined;
			EndIf;
			
			Try
				ZipReading.ExtractAll(FolderForUnpacking);
			Except
				ErrorText = BriefErrorDescription(ErrorInfo());
				If Not ElectronicDocumentsService.PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
					MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
				EndIf;
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED package Unpacking';ru='распаковка пакета ЭД'"),
					ErrorText, MessageText);
				ZipReading.Close();
				DeleteFiles(FolderForUnpacking);
				Return Undefined;
			EndTry;
			
			ViewingFlag = False;
									
			XMLArchiveFiles = FindFiles(FolderForUnpacking, "*.xml");
			
			For Each UnpackedFile IN XMLArchiveFiles Do
				
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(
					UnpackedFile.FullName, LinkToED.EDDirection, LinkToED.UUID());
					
				If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
					Return SpreadsheetDocument;
				EndIf;
				
			EndDo;
			
			MXLArchiveFiles = FindFiles(FolderForUnpacking, "*.mxl");
			For Each UnpackedFile IN MXLArchiveFiles Do
				DataFileName = UnpackedFile.FullName;
				SpreadsheetDocument = New SpreadsheetDocument;
				SpreadsheetDocument.Read(DataFileName);
				DeleteFiles(FolderForUnpacking);
				Return SpreadsheetDocument;
			EndDo;
			
			DeleteFiles(FolderForUnpacking);

		ElsIf Find(AdditInformationAboutED.Extension, "xml") > 0 Then
			If LinkToED.EDKind = Enums.EDKinds.Confirmation
				OR LinkToED.EDKind = Enums.EDKinds.NotificationAboutReception
				OR LinkToED.EDKind = Enums.EDKinds.NotificationAboutClarification
				OR LinkToED.EDKind = Enums.EDKinds.CancellationOffer
				OR LinkToED.EDKind = Enums.EDKinds.TORG12Seller
				OR LinkToED.EDKind = Enums.EDKinds.ActPerformer
				OR LinkToED.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender
				OR LinkToED.EDKind = Enums.EDKinds.CustomerInvoiceNote
				OR LinkToED.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
				
				SelectionEDAddData = ElectronicDocumentsService.SelectionAdditDataED(LinkToED);
				If SelectionEDAddData.Next() Then
					AdditDataED = ElectronicDocumentsService.GetFileData(SelectionEDAddData.Ref,
					                                                                SelectionEDAddData.Ref.UUID(),
					                                                                True);
					RefToDDAdditDataED = "";
					If AdditDataED.Property("FileBinaryDataRef", RefToDDAdditDataED)
						AND ValueIsFilled(RefToDDAdditDataED) Then
						AdditFileData = GetFromTempStorage(RefToDDAdditDataED);
					
						If ValueIsFilled(AdditDataED.Extension) Then
							AdditDataFileName = ElectronicDocumentsService.TemporaryFileCurrentName(AdditDataED.Extension);
						Else
							AdditDataFileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
						EndIf;
					
						If AdditDataFileName = Undefined Then
							ErrorText = NStr("en='Unable to get additional data of the electronic document.
		|Verify the work directory setting';ru='Не удалось получить доп. данные электронного документа.
		|Проверьте настройку рабочего каталога'");
							CommonUseClientServer.MessageToUser(ErrorText);
							Return Undefined;
						EndIf;
						AdditFileData.Write(AdditDataFileName);
					EndIf;
				EndIf;
				
				DataFileName = FileName;
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(FileName, LinkToED.EDDirection,
													LinkToED.UUID(), SubordinatedEDFileName, AdditDataFileName);
													
				If Not AdditDataFileName = Undefined Then
					DeleteFiles(AdditDataFileName);
				EndIf;
				If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
					Return SpreadsheetDocument;
				EndIf;
			
			ElsIf LinkToED.EDKind = Enums.EDKinds.PaymentOrder
				OR LinkToED.EDKind = Enums.EDKinds.QueryStatement
				OR LinkToED.EDKind = Enums.EDKinds.BankStatement
				OR LinkToED.EDKind = Enums.EDKinds.STATEMENT Then
			
				DataFileName = FileName;
				SpreadsheetDocument = ElectronicDocumentsInternal.GenerateEDPrintForm(
					FileName, LinkToED.EDDirection, LinkToED.UUID(), SubordinatedEDFileName);
			
				If TypeOf(SpreadsheetDocument)=Type("SpreadsheetDocument") Then
					Return SpreadsheetDocument;
				EndIf;

			EndIf;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Procedure ProcessObjectTypeSelection()
	
	If ValueIsFilled(ObjectType) Then
		For Each Item IN TypeList Do
			If Item.Presentation = ObjectType Then
				SelectedRefs = Item.Value;
				If Not ValueIsFilled(IBDocument) OR TypeOf(IBDocument) <> TypeOf(SelectedRefs) Then
					IBDocument = SelectedRefs;
				EndIf;
				Break;
			EndIf;
		EndDo;
	EndIf;

EndProcedure

&AtClient
Procedure GenerateServiceMessageText()
	
	If ValueIsFilled(FileNameCML) Then
		
		ItemTitle = NStr("en='Failed to read the file';ru='Не удалось прочитать файл'"+ FileNameCML+".""'");
		
	Else
		
		ItemTitle = NStr("en='""*.xml"" file of the electronic document is not found.';ru='Не найден файл электронного документа ""* .xml.""'");
		
	EndIf;
	
	Items.CommentServiceMessage.Title = ItemTitle;
	
EndProcedure

&AtClient
Procedure ImportCompanyAttributes()
	
	Cancel = False;
	MessageText = "";
	
	If DocumentImportMethod = 1 AND Not ValueIsFilled(IBDocument) Then
		MessageText = NStr("en='Catalog item to be refilled is not specified.';ru='Не указан элемент справочника для перезаполнения.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Cancel = True;
	EndIf;
	
	CreateIBObjects(AddressStructureEDParsing, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
		
	FormData = Undefined;
	If Not CreateDocumentForIB(FormData, MessageText, True) Then
		Cancel = True;
	EndIf;
	
	
	If Cancel Then
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	FormParameters = New Structure("Key", FormData);
	OpeningMode = FormWindowOpeningMode.Independent;
	
	OpenForm(MetadataObjectName +".Form.ItemForm",FormParameters,,,,,,OpeningMode);
	
EndProcedure

&AtClient
Procedure ImportProductsDirectory()
	
	CreateIBObjects(AddressStructureEDParsing, False);
	
	NotificationHandler = New NotifyDescription("ImportNotificationDirectory", ThisObject) ;
	
	CompareProductsAndServices(NotificationHandler);
	
	Close();
	
EndProcedure

&AtClient
Procedure ImportDocumentEDF()
	
	Cancel = False;
	MessageText = "";
	
	If Not CanImportEDWithType(EDKind) Then
		MessageText = NStr("en='Import of electronic documents of the ""%1"" kind is not supported.';ru='Не поддерживается загрузка электронных документов вида ""%1"".'");
		MessageText = StrReplace(MessageText, "%1", ObjectType);
		CommonUseClientServer.MessageToUser(MessageText);
		Cancel = True;
	EndIf;
	
	If Not ValueIsFilled(Counterparty) Then
		MessageText = NStr("en='Counterparty is not specified.';ru='Не указан контрагент.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Cancel = True;
	EndIf;
	
	If DocumentImportMethod = 1 AND Not ValueIsFilled(IBDocument) Then
		MessageText = NStr("en='Document for refilling is not specified.';ru='Не указан документ для перезаполнения.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Cancel = True;
	EndIf;
	
	CreateIBObjects(AddressStructureEDParsing, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	CompareProductsAndServicesBeforeDocumentFilling = False;
	ElectronicDocumentsClientOverridable.CompareProductsAndServicesBeforeDocumentFilling(CompareProductsAndServicesBeforeDocumentFilling);
	
	If CompareProductsAndServicesBeforeDocumentFilling Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Cancel", Cancel);
		
		
		NotificationHandlerBeforeFilling = New NotifyDescription("MapBeforeFillingAlert",
			ThisObject,
			AdditionalParameters);
		CompareProductsAndServices(NotificationHandlerBeforeFilling);
	Else
		ImportDocumentInIB(CompareProductsAndServicesBeforeDocumentFilling, Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDocumentInIB(CompareProductsAndServicesBeforeDocumentFilling, Cancel)
	
	Try
		
		If DocumentImportMethod = 1 AND ValueIsFilled(IBDocument) Then
			DocumentForm = GetForm(MetadataObjectName + ".ObjectForm", New Structure("Key", IBDocument));
		Else
			DocumentForm = GetForm(MetadataObjectName + ".ObjectForm");
		EndIf;
		
	Except
		
		MessageText = BriefErrorDescription(ErrorInfo());
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
		
	EndTry;
	
	If Not Cancel Then
		
		If TypeOf(DocumentForm) = Type("ManagedForm") Then
			FormData = DocumentForm.Object;
		Else
			FormData = Undefined;
		EndIf;
		
		If Not CreateDocumentForIB(FormData, MessageText) Then
			Cancel = True;
		EndIf;
		
		If Cancel Then
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			
			If Not CompareProductsAndServicesBeforeDocumentFilling Then
				
				AdditionalParameters = New Structure;
				AdditionalParameters.Insert("FormData", FormData);
				AdditionalParameters.Insert("DocumentForm", DocumentForm);
				
				HandlerAfterDocumentFilling = New NotifyDescription("MapAfterFillingAlert", ThisObject, AdditionalParameters);
				
				CompareProductsAndServices(HandlerAfterDocumentFilling);
				
			EndIf;
			
			FillDocumentWithFormData(DocumentForm, FormData);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillDocumentWithFormData(DocumentForm, FormData)
	
	If TypeOf(DocumentForm) = Type("ManagedForm") Then
		CopyFormData(FormData, DocumentForm.Object);
	Else
		DocumentForm.DocumentObject = FormData;
	EndIf;
	
	InformationArray = New Array;
	InformationArray.Add(IBDocument);
	Notify("UpdateIBDocumentAfterFillingFromFile", InformationArray);
	
	DocumentForm.Open();
	DocumentForm.Modified = True;
	
EndProcedure

#EndRegion

#Region CommandsActionsForms

&AtClient
Procedure ExecuteAction(Command)
	
	If EDImport AND ValueIsFilled(MetadataObjectName) Then
		
		ClearMessages();
		
		If Upper(EDKind) = Upper("CompanyAttributes") Then
			
			ImportCompanyAttributes();
			
		Else
			
			ImportDocumentEDF();
			
		EndIf;
		
	EndIf;
	
	If EDKind = PredefinedValue("Enum.EDKinds.ProductsDirectory") Then
		
		ImportProductsDirectory();
		
	EndIf;
	
	ThisObject.Close();
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure DocumentImportMethodOnChange(Item)
	
	ChangeVisibleEnabled();
	
EndProcedure

&AtClient
Procedure CatalogImportMethodOnChange(Item)
	
	ChangeVisibleEnabled();
	
EndProcedure

&AtClient
Procedure ObjectTypeOnChange(Item)
	
	ProcessObjectTypeSelection();
	
EndProcedure

&AtClient
Procedure CatalogTypesListOnChange(Item)
	
	ProcessObjectTypeSelection();
	
EndProcedure

&AtClient
Procedure IBDocumentChoiceBegin(Item, ChoiceData, StandardProcessing)
	
	If IBDocument = Undefined Then
		CurItem = Undefined;
		If ValueIsFilled(ObjectType) Then
			For Each ItemOfList IN TypeList Do
				If ObjectType = ItemOfList.Presentation Then
					IBDocument = ItemOfList.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	EDStructure = "";
	EDDirection = "";
	If Parameters.Property("EDStructure", EDStructure) AND TypeOf(EDStructure) = Type("Structure")
		AND EDStructure.Property("EDDirection", EDDirection) Then
		
		EDImport = (EDDirection = Enums.EDDirections.Incoming);
		
		EDStructure.Property("EDOwner", IBDocument);
		If EDImport Then
			
			LinkToDocumentToBeFilled = "";
			If EDStructure.Property("DocumentRef", LinkToDocumentToBeFilled)
				AND ValueIsFilled(LinkToDocumentToBeFilled) Then
				
				DocumentImportMethod = 1;
			EndIf;
		EndIf;
		ToViewEDServer(EDStructure, Cancel);
	EndIf;
	
	ElectronicDocument = Undefined;
	If Parameters.Property("ElectronicDocument", ElectronicDocument) Then
		EDImport = False;
		Parameters.Property("EDOwner", IBDocument);
		EDData = EDDataFile(ElectronicDocument);
		If EDData = Undefined Then
			Return;
		EndIf;
		If TypeOf(EDData) = Type("SpreadsheetDocument") Then
			FormTableDocument = EDData;
		EndIf;
	EndIf;
	
	ChangeVisibleOfEnabledWhenCreatingServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ChangeVisibleEnabled();
	
	If IsTempStorageURL(AddressStructureEDParsing) AND ValueIsFilled(FileExtension) Then
		#If WebClient Then
			PathToViewingFile = AddressStructureEDParsing;
		#Else
			PathToViewingFile = GetTempFileName(FileExtension);
			QQFile = GetFromTempStorage(AddressStructureEDParsing);
			QQFile.Write(PathToViewingFile);
		#EndIf
		If Find("HTML PDF DOCX XLSX", Upper(FileExtension)) > 0 Then
			
			GenerateServiceMessageText();
			
			Items.Panel.CurrentPage = Items.ViewED;
			
		Else
			#If Not WebClient Then
				RunApp(PathToViewingFile);
			#EndIf
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
	
EndProcedure

#EndRegion

#Region AsynchronousProcedures

&AtClient
Procedure ImportNotificationDirectory(Result, AdditionalParameters) Export
	
	SaveVBDObjectData(AddressStructureEDParsing);
	Close();
	
EndProcedure

&AtClient
Procedure MapBeforeFillingAlert(Result, AdditionalParameters) Export
	
	Cancel = AdditionalParameters.Cancel;
	
	ImportDocumentInIB(True, Cancel);
	
EndProcedure

&AtClient
Procedure MapAfterFillingAlert(Result, AdditionalParameters) Export
	
	FormData = AdditionalParameters.FormData;
	DocumentForm = AdditionalParameters.DocumentForm;
	
	If ValueIsFilled(Result) Then
		ElectronicDocumentsServiceCallServer.FillSource(FormData, Result);
	EndIf;
	
	FillDocumentWithFormData(DocumentForm, FormData);
	
EndProcedure

#EndRegion














