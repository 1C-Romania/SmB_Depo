////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("ElectronicDocument") Then
		ElectronicDocument = Parameters.ElectronicDocument;
		If TypeOf(ElectronicDocument) = Type("CatalogRef.EDAttachedFiles") Then
			Items.EDPresentation.Title = ElectronicDocumentsService.GetEDPresentation(ElectronicDocument);
		EndIf;
	EndIf;
	
	If Parameters.Property("DoNotOpenFormOnUncomparedProductsAndServicesAbsence") Then
		DoNotOpenFormOnUncomparedProductsAndServicesAbsence = Parameters.DoNotOpenFormOnUncomparedProductsAndServicesAbsence;
	EndIf;
	
	If Not ValueIsFilled(ElectronicDocument) Then
		MessageText = NStr("en='Electronic document has not been selected';ru='Не выбран электронный документ'");
		CommonUseClientServer.MessageToUser(MessageText, , "ElectronicDocument", , Cancel);
		Return;
	EndIf;
	
	If TypeOf(ElectronicDocument) = Type("Structure") Then
		// ElectronicDocument in case of mapping in a single transaction - structure.
		EDOwner = ElectronicDocument.FileOwner;
		EDKind = ElectronicDocument.EDKind;
	Else
		EDAttributes = CommonUse.ObjectAttributesValues(ElectronicDocument, "FileOwner, EDKind");
		EDOwner  = EDAttributes.FileOwner;
		EDKind       = EDAttributes.EDKind;
	EndIf;
	
	If ElectronicDocument.EDKind = Enums.EDKinds.CustomerInvoiceNote
		OR ElectronicDocument.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
		
		CloseOnClient = True;
		Return;
	EndIf;
	
	Counterparty = ElectronicDocument.Counterparty;
	
	ReadCounterpartyProductsAndServicesServer();
	
	If DoNotOpenFormOnUncomparedProductsAndServicesAbsence
		AND UncomparedCounterpartyProductsAndServices.Count() = 0 Then
		// Do not need to open the form
		CloseOnClient = True;
		
		If EDKind = Enums.EDKinds.ProductsDirectory
			AND TypeOf(ElectronicDocument) = Type("CatalogRef.EDAttachedFiles") Then
			
			SaveDirectoryData(ElectronicDocument);
		EndIf;
		
	EndIf;
	
	// Data processor of the "ProductsAndServices" column.
	CatalogNameProductsAndServices = ElectronicDocumentsReUse.GetAppliedCatalogName("ProductsAndServices");
	ProductsAndServicesType = New TypeDescription("CatalogRef." + CatalogNameProductsAndServices);
	Items.NewCounterpartyProductsAndServicesProductsAndServices.TypeRestriction = ProductsAndServicesType;
	
	// Data processor of the "Products and services characteristic" column.
	ProductsAndServicesCharacteristicsAreUsed = ElectronicDocumentsReUse.AdditionalAnalyticsCatalogProductsAndServicesCharacteristics();
	Items.NewCounterpartyProductsAndServicesProductsAndServicesCharecteristic.Visible = ProductsAndServicesCharacteristicsAreUsed;
	If ProductsAndServicesCharacteristicsAreUsed Then
		
		CatalogNameProductsAndServicesCharacteristics = ElectronicDocumentsReUse.GetAppliedCatalogName(
			"ProductsAndServicesCharacteristics");
		ProductsAndServicesCharacteristicType = New TypeDescription("CatalogRef." + CatalogNameProductsAndServicesCharacteristics);
		Items.NewCounterpartyProductsAndServicesProductsAndServicesCharecteristic.TypeRestriction = ProductsAndServicesCharacteristicType;
	
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CloseOnClient Then
		RefillED();
		Cancel = True
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	RefillED();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure EDPresentationClick(Item)
	
	ElectronicDocumentsServiceClient.OpenEDForViewing(ElectronicDocument);
	
EndProcedure

&AtClient
Procedure NewCounterpartyProductsAndServicesProductsAndServicesStartChoice(Item, ChoiceData, StandardProcessing)
	
	ParametersStructure = New Structure("Counterparty", Counterparty);
	ElectronicDocumentsClientOverridable.ProductsAndServicesMappingFormOpen(
															Item,
															ParametersStructure,
															StandardProcessing);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure ReadCounterpartyProductsAndServices(Command)
	
	If Modified Then
		
		QuestionText = NStr("en='Unsaved changes will be lost.
		|Continue?';ru='Несохраненные изменения будут утеряны.
		|Продолжить?'");
			
		NotificationHandler = New NotifyDescription("ReadProductsAndServicesNotification", ThisObject);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo,,, "Filling the products and services list");
		
	Else
		ReadCounterpartyProductsAndServicesServer();
		Modified = False;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure ReadProductsAndServicesNotification(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return
	EndIf;
	
	ReadCounterpartyProductsAndServicesServer();
	Modified = False;
	
EndProcedure

&AtClient
Procedure RecordCounterpartyProductsAndServices(Command)
	
	Cancel = False;
	WriteCounterpartyProductsAndServicesServer(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENTS HANDLERS OF THE UNMAPPED PRODUCTS AND SERVICES COUNTERPARTY TABLE FIELDS

&AtClient
Procedure UncomparedCounterpartyProductsAndServicesOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure UncomparedCounterpartyProductsAndServicesOnStartEdit(Item, NewRow, Copy)
	If Item.CurrentItem.Name = "NewCounterpartyCounterpartyProductsAndServicesProductsAndServicesDescription" Then
		ElectronicDocumentsClientOverridable.OpenSupplierProductsAndServicesElement(Item.CurrentData.ID);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServerNoContext
Procedure SaveDirectoryData(LinkToED)
	
	ThisIsSingleTransaction = False;
	
	If TypeOf(LinkToED) = Type("CatalogRef.EDAttachedFiles") Then
		AdditInformationAboutED = AttachedFiles.GetFileData(LinkToED,
		                                                            LinkToED.UUID(),
		                                                            True);
	ElsIf TypeOf(LinkToED) = Type("Structure") Then // single transaction
		AdditInformationAboutED = New Structure;
		
		AdditInformationAboutED.Insert("FileBinaryDataRef", LinkToED.ParseFileData);
		AdditInformationAboutED.Insert("Extension", "xml");
		ThisIsSingleTransaction = True;
	EndIf;
	
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
			Return;
		EndIf;
		
		If Not ThisIsSingleTransaction Then
			SelectionEDAddData = ElectronicDocumentsService.SelectionAdditDataED(LinkToED);
			If SelectionEDAddData.Next() Then
				AdditDataED = AttachedFiles.GetFileData(
																SelectionEDAddData.Ref,
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
		| Verify the work directory setting';ru='Не удалось получить доп. данные электронного документа.
		| Проверьте настройку рабочего каталога'");
						CommonUseClientServer.MessageToUser(ErrorText);
						Return;
					EndIf;
					AdditFileData.Write(AdditDataFileName);
				EndIf;
			EndIf;
		EndIf;
		
		EDData.Write(FileName);
		
		If Find(AdditInformationAboutED.Extension, "zip") > 0 Then
			ZIPReading = New ZipFileReader(FileName);
			FolderForUnpacking = ElectronicDocumentsService.WorkingDirectory( , LinkToED.UUID());
			
			If FolderForUnpacking = Undefined Then
				ErrorText = NStr("en='Unable to view electronic document. Verify the work directory setting';ru='Не удалось просмотреть электронный документ. Проверьте настройку рабочего каталога'");
				CommonUseClientServer.MessageToUser(ErrorText);
				ZIPReading.Close();
				DeleteFiles(FileName);
				Return;
			EndIf;
			
			Try
				ZipReading.ExtractAll(FolderForUnpacking);
			Except
				ErrorText = BriefErrorDescription(ErrorInfo());
				If Not ElectronicDocumentsService.PossibleToExtractFiles(ZipReading, FolderForUnpacking) Then
					MessageText = ElectronicDocumentsReUse.GetMessageAboutError("006");
				EndIf;
				Operation = NStr("en='ED unpacking';ru='Распаковка ЭД'");
				ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(Operation,
																							ErrorText,
																							MessageText);
				ZIPReading.Close();
				DeleteFiles(FileName);
				DeleteFiles(FolderForUnpacking);
				Return;
			EndTry;
			
			XMLArchiveFiles = FindFiles(FolderForUnpacking, "*.xml");
			For Each UnpackedFile IN XMLArchiveFiles Do
				DataFileName = UnpackedFile.FullName;
			EndDo;
			
		ElsIf Find(AdditInformationAboutED.Extension, "xml") > 0 Then
			
			DataFileName = FileName;
			
		EndIf;
		
		ParcingStructure = ElectronicDocumentsInternal.GenerateParseTree(DataFileName,
																					Enums.EDDirections.Incoming,
																					,
																					AdditDataFileName);
																					
		DeleteFiles(FileName);
		If Not AdditDataFileName = Undefined Then
			DeleteFiles(AdditDataFileName);
		EndIf;

		If ValueIsFilled(FolderForUnpacking) Then
			DeleteFiles(FolderForUnpacking);
		EndIf;
		
		If ParcingStructure <> Undefined AND ParcingStructure.Property("ParseTree") Then
			ElectronicDocumentsOverridable.SaveVBDObjectData(
											ParcingStructure.ObjectString,
											ParcingStructure.ParseTree);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefillED()
	
	If ValueIsFilled(EDOwner) Then
		ElectronicDocumentsClient.RefillDocument(
			EDOwner,
			,
			True,
			?(TypeOf(ElectronicDocument) = Type("Structure"), Undefined, ElectronicDocument));
	EndIf;
		
EndProcedure

&AtServer
Function QuickExchangeTableInformationAboutProduct(ED)
	
	Var ReturnTable;
	TempFile = GetTempFileName("xml");
	BinaryDataParseFile = GetFromTempStorage(ED.ParseFileData);
	BinaryDataParseFile.Write(TempFile);
	ElectronicDocumentsInternal.InformationAboutProductFromXMLFile(TempFile, ReturnTable, ED);
	DeleteFiles(TempFile);
	
	Return ReturnTable;
	
EndFunction

&AtServer
Procedure ReadCounterpartyProductsAndServicesServer()
	
	Query = New Query;
	ElectronicDocumentsOverridable.ProductsAndServicesCorrespondenceQueryText(Query.Text);
	
	If Not ValueIsFilled(Query.Text) Then
		MessageText = NStr("en='The mapping of products and services and suppliers products and services is not defined.
		|It is required to fill the ElectronicDocumentsOverridable procedure.ProductsAndServicesCorrespondenceQueryText.';ru='Не определено сопоставление номенклатуры и номенклатуры поставщиков. Необходимо заполнить процедуру ЭлектронныеДокументыПереопределяемый.ТекстЗапросаСопоставленияНоменклатуры.'");
		Raise(MessageText);
	EndIf;
	
	If TypeOf(ElectronicDocument) = Type("CatalogRef.EDAttachedFiles") Then
		EDKindsArray = New Array;
		EDKindsArray.Add(ElectronicDocument);
		TableInformationAboutProduct = ElectronicDocumentsInternal.GetInformationAboutProduct(EDKindsArray);
	Else
		TableInformationAboutProduct = QuickExchangeTableInformationAboutProduct(ElectronicDocument);
	EndIf;
	
	If TableInformationAboutProduct = Undefined Then
		Return;
	EndIf;
	
	Query.SetParameter("TableInformationAboutProduct", TableInformationAboutProduct);
	Query.SetParameter("Counterparty", Counterparty);
	
	VTComparison = Query.Execute().Unload();
	VTComparison.GroupBy("CounterpartyProductsAndServicesSKU, CounterpartyProductsAndServicesDescription, CounterpartyProductsAndServicesUnit, Description, Identifier");
	
	UncomparedCounterpartyProductsAndServices.Load(VTComparison);
	
EndProcedure

&AtServer
Procedure WriteCounterpartyProductsAndServicesServer(Cancel = False)
	
	ElectronicDocumentsOverridable.WriteProductsAndServicesComparison(
																		UncomparedCounterpartyProductsAndServices,
																		Counterparty,
																		Cancel);
	If EDKind = Enums.EDKinds.ProductsDirectory Then
		SaveDirectoryData(ElectronicDocument);
	EndIf;
	
EndProcedure






// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
