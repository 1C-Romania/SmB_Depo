////////////////////////////////////////////////////////////////////////////////
// GENERAL PROCEDURES AND FUNCTIONS WORKING WITH DOCUMENTS

Procedure DocumentsBeforeWriteAll(Source, Cancel, WriteMode, PostingMode) Export
	
	Source.AdditionalProperties.Insert("WriteMode",   WriteMode);
	Source.AdditionalProperties.Insert("PostingMode", PostingMode);
	If CommonAtServer.IsDocumentAttribute("Company", Source.Metadata()) Then
		Source.AdditionalProperties.Insert("RefCompany", ?(ValueIsFilled(Source.Ref.Company),Source.Ref.Company,Source.Company));
		
		If Not ValueIsFilled(Source.Company) 
			OR NOT CommonAtServer.UseMultiCompaniesMode() Then
			
			Source.Company	= DefaultValuesAtServer.GetDefaultCompany(DefaultValuesAtServer.GetCurrentUser());
			
		EndIf;
		
	EndIf;	
	Alerts.ClearAlertsTable(Source);

	// Jack 29.05.2017
	//IsBankRecorder = Source.Metadata().RegisterRecords.Contains(Metadata.AccumulationRegisters.Bank);
	//If IsBankRecorder Then
	//	BankCash.FillCostOfCurrenciesSequenceTables(Source, "Bank");
	//EndIf;
	//
	//IsCashRecorder = Source.Metadata().RegisterRecords.Contains(Metadata.AccumulationRegisters.Cash);
	//If IsCashRecorder Then
	//	BankCash.FillCostOfCurrenciesSequenceTables(Source, "Cash");
	//EndIf;
	
	//IsCostOfGoodsRecorder = Source.Metadata().RegisterRecords.Contains(Metadata.AccumulationRegisters.CostOfGoods);
	//IsCostOfGoodsTurnoversRecorder = Source.Metadata().RegisterRecords.Contains(Metadata.AccumulationRegisters.CostOfGoodsTurnovers);
	//IsCostOfGoodsPurchaseOrderRecorder = TypeOf(Source)=Type("DocumentObject.PurchaseInvoice") AND Source.Metadata().RegisterRecords.Contains(Metadata.AccumulationRegisters.PurchaseOrders);
	//If IsCostOfGoodsRecorder Or IsCostOfGoodsTurnoversRecorder OR IsCostOfGoodsPurchaseOrderRecorder Then
	//	CostOfGoodsSequenceAtServer.FillCostOfGoodsSequenceTables(Source);
	//EndIf;	
	//
	//
	//If Source.AdditionalProperties.Property("CostOfGoodsSequenceRestoring") Then
	//	If IsCostOfGoodsRecorder Then
	//		CostOfGoodsBeforeWriteValueTable = Comparison.GetValueTableFromRecordSet("CostOfGoods",Source.Ref);
	//		Source.AdditionalProperties.Insert("CostOfGoodsBeforeWriteValueTable",   CostOfGoodsBeforeWriteValueTable);
	//		Source.AdditionalProperties.Insert("IsCostOfGoodsRecorder");
	//	EndIf;	
	//	
	//	If IsCostOfGoodsTurnoversRecorder Then
	//		CostOfGoodsTurnoversBeforeWriteValueTable = Comparison.GetValueTableFromRecordSet("CostOfGoodsTurnovers",Source.Ref);
	//		Source.AdditionalProperties.Insert("CostOfGoodsTurnoversBeforeWriteValueTable",   CostOfGoodsTurnoversBeforeWriteValueTable);
	//		Source.AdditionalProperties.Insert("IsCostOfGoodsTurnoversRecorder");
	//	EndIf;	
	//EndIf;
	
	If WriteMode = DocumentWriteMode.UndoPosting Then
		Source.AdditionalProperties.Insert("MessageTitle", NStr("en='Clear posting document:';pl='Anulowanie zatwierdzenia dokumentu:'") + " " + TrimAll(Source));
	EndIf;
		
EndProcedure

Procedure DocumentsOnWriteAll(Source, Cancel) Export
	
	If Not Cancel then
		AdditionalAttributesServer.WrireAdditionalAttributeValues(Source);
	EndIf;	
	
	// Jack 29.05.2017
	//If Source.AdditionalProperties.Property("FirstNumber") Then
	//	SetPrivilegedMode(True);
	//	RefreshObjectsNumbering(Source.Metadata());
	//	SetPrivilegedMode(False);
	//EndIf;	
	
	If Source.AdditionalProperties.WriteMode = DocumentWriteMode.Posting Then
		Source.AdditionalProperties.Insert("MessageTitle", NStr("en='Posting document:';pl='Zatwierdzenie dokumentu:'") + " " + TrimAll(Source));		
	ElsIf Source.AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		Source.AdditionalProperties.Insert("MessageTitle", NStr("en='Write document:';pl='Zapis dokumentu:'") + " " + TrimAll(Source));
	EndIf;	
	
	If Source.AdditionalProperties.WriteMode = DocumentWriteMode.Posting Then
		DocumentsPostingAndNumbering.CheckPostingPermission(Source, Cancel, Source.AdditionalProperties.MessageTitle);
	ElsIf Source.AdditionalProperties.WriteMode = DocumentWriteMode.UndoPosting Then
		DocumentsPostingAndNumbering.CheckUndoPostingPermission(Source, Cancel, Source.AdditionalProperties.MessageTitle);
	EndIf;
	
EndProcedure

Procedure DocumentsPostingAll(Source, Cancel, PostingMode) Export
	
	For Each RecordSet In Source.RegisterRecords Do
		RecordSet.AdditionalProperties.Insert("IsPostingWrite",True);
	EndDo;	
		
EndProcedure

// Jack 29.05.2017
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH DOCUMENT MANAGERS

//Procedure DocumentsPresentationGetProcessing(Source, Data, Presentation, StandardProcessing) Export
//	
//	PresentationType = CommonUseCached.GetCurrentUserDocumentPresentationType();
//	
//	// StandardProcessing is False means that something was done before and we should skip
//	If StandardProcessing = False Then
//		Return;
//	EndIf;
//	
//	If PresentationType = Enums.DocumentPresentationType.TypeNumberDate Then
//		Return; // Standard platform presentation, do nothing.
//	EndIf;
//	
//	// For back compatibility redefine empty value to the default value
//	If PresentationType = PresentationType = Enums.DocumentPresentationType.EmptyRef() Then
//		PresentationType = Enums.DocumentPresentationType.NumberDate;
//	EndIf;
//	
//	StandardProcessing = False;
//	
//	Presentation = ?(Data.Property("Number"), TrimAll(Data.Number), "");
//	If PresentationType = Enums.DocumentPresentationType.NumberDate Then
//		PresentationDate = ?(Data.Property("Date"), Data.Date, "");
//		Presentation = Presentation + " " + NStr("en = 'date'; pl = 'z'") + " " + PresentationDate;
//	EndIf;
//	
//EndProcedure

//////////////////////////////////////////////////////////////////////////////////
//// PROCEDURES AND FUNCTIONS WORKING WITH DOCUMENTS NUMBERING

//Procedure SetDocumentNumberPrefixOnSetNewNumber(Source, StandardProcessing, Prefix) Export
//	
//	If Source.DataExchange.Load = True Then
//		Return;
//	EndIf;	
//	
//	If IsBlankString(Prefix) Then
//		Prefix = DocumentsPostingAndNumbering.GetDocumentNumberPrefix(Source);
//	EndIf;
//	
//EndProcedure

//Procedure SetDocumentNumberBeforeWriteBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
//	
//	If Source.DataExchange.Load = True Then
//		Return;
//	EndIf;	
//	If Source.ManualChangeNumber Then
//		Return;
//	EndIf;
//	If Source.IsNew() Or (Not Source.ManualChangeNumber And TrimAll(Source.Number) = "") Then
//		
//		DocumentsPostingAndNumbering.SetNewDocumentPrefix(Source, Cancel);
//		
//	Else
//		
//		If Source.Date <> Source.Ref.Date
//			Or (CommonAtServer.IsDocumentAttribute("Company", Source.Metadata()) And Source.Company <> Source.Ref.Company)
//			Or (SessionParameters.IsBookkeepingAvailable AND TypeOf(Source) = Type("DocumentObject.BookkeepingOperation") And Source.PartialJournal <> Source.Ref.PartialJournal) Then
//			
//			CurrentPrefix = DocumentsPostingAndNumbering.GetDocumentNumberPrefix(Source);
//			
//			If Left(Source.Number, StrLen(CurrentPrefix)) <> CurrentPrefix Then
//				
//				If IsInRole(Metadata.Roles.Right_General_ModifyDocumentsNumber) Then
//					Alerts.AddAlert(Alerts.ParametrizeString(NStr("en = 'ATTENTION! Document %P1 should be renumbered manually! Awaited number should contains prefix %P2.'; pl = 'UWAGA! Dokument %P1 ma być przenumerowany ręcznie! Oczekiwany prefiks numeru dokumentu to %P2.'"),New Structure("P1, P2",TrimAll(Source),CurrentPrefix)),, Cancel,Source);
//				Else
//					Alerts.AddAlert(Alerts.ParametrizeString(NStr("en=""You cannot change document's date or company because the document %P1 should be renumbered!"";pl='Nie wolno zmieniać numeru dokumentu ani firmy, gdyż ten dokument %P1 musi być przenumerowany!'"),New Structure("P1",TrimAll(Source))),, Cancel,Source);
//				EndIf;
//				
//			EndIf;
//			
//		EndIf;
//		
//	EndIf;
//	
//EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH DOCUMENTS DEPENDENCE

//Procedure SetDocumentDependencePosting(Source, Cancel, PostingMode) Export
//	
//	RecordsValue = New ValueTable();
//	RecordsValue.Columns.Add("Period", Common.GetDateTypeDescription());
//	RecordsValue.Columns.Add("ParentDocument",Documents.AllRefsType());
//	
//	ObjectMetadata = Source.Metadata();
//	For Each Attribute In ObjectMetadata.Attributes Do
//		
//		If Documents.AllRefsType().ContainsType(TypeOf(Source[Attribute.Name])) AND Source[Attribute.Name]<>Undefined Then
//			
//			If NOT Source[Attribute.Name].IsEmpty() Then
//				
//				If RecordsValue.Find(Source[Attribute.Name],"ParentDocument") = Undefined Then
//					
//					If NOT (((TypeOf(Source.Ref) = TypeOf(Documents.SalesDelivery.EmptyRef()) 
//						AND TypeOf(Source[Attribute.Name]) = TypeOf(Documents.SalesInvoice.EmptyRef())) 
//						OR (TypeOf(Source.Ref) = TypeOf(Documents.SalesReturnReceipt.EmptyRef())
//						AND TypeOf(Source[Attribute.Name]) = TypeOf(Documents.SalesCreditNoteReturn.EmptyRef())) )
//						AND Source[Attribute.Name].ImmediateStockMovements) Then
//						
//						RecordsValueRow = RecordsValue.Add();
//						RecordsValueRow.Period			= Source.Date;
//						RecordsValueRow.ParentDocument	= Source[Attribute.Name];
//						
//					EndIf;
//					
//				EndIf;
//				
//			EndIf;	
//			
//		EndIf;	
//		
//	EndDo;	
//	
//	// Tabular sections
//	For Each TabularSection In ObjectMetadata.TabularSections Do
//		
//		DocumentTypeAttributesArray = New Array();
//		For Each Attribute In TabularSection.Attributes Do

//			For Each AttributeType In Attribute.Type.Types() Do
//				If Documents.AllRefsType().ContainsType(AttributeType) Then
//					DocumentTypeAttributesArray.Add(Attribute.Name);
//					Break;
//				EndIf;	
//			EndDo;	
//			
//		EndDo;	
//		
//		If DocumentTypeAttributesArray.Count()>0 Then
//			
//			For Each TabularSectionRow In Source[TabularSection.Name] Do
//				
//				For Each DocumentTypeAttributeName In DocumentTypeAttributesArray Do
//					
//					If Documents.AllRefsType().ContainsType(TypeOf(TabularSectionRow[DocumentTypeAttributeName])) AND TabularSectionRow[DocumentTypeAttributeName]<>Undefined Then
//						
//						If NOT TabularSectionRow[DocumentTypeAttributeName].IsEmpty() Then
//							
//							If RecordsValue.Find(TabularSectionRow[DocumentTypeAttributeName],"ParentDocument") = Undefined Then
//								
//								RecordsValueRow = RecordsValue.Add();
//								RecordsValueRow.Period			= Source.Date;
//								RecordsValueRow.ParentDocument	= TabularSectionRow[DocumentTypeAttributeName];
//								
//							EndIf;

//						EndIf;	
//						
//					EndIf;	
//					
//				EndDo;
//				
//			EndDo;	
//			
//		EndIf;
//		
//	EndDo;	
//	
//	Source.RegisterRecords.DocumentHierarchy.Load(RecordsValue);
//	Source.RegisterRecords.DocumentHierarchy.Write = True;
//	
//	Query = New Query;
//	Query.Text = "SELECT
//	             |	DocumentsAcceptanceSliceLast.Document,
//	             |	DocumentsAcceptanceSliceLast.Schema,
//	             |	DocumentsAcceptanceSliceLast.Schema.BlockNestedDocuments AS BlockNestedDocuments,
//	             |	DocumentsAcceptanceSliceLast.NextUser
//	             |FROM
//	             |	InformationRegister.DocumentsAcceptance.SliceLast(, Document IN (&DocumentsArray)) AS DocumentsAcceptanceSliceLast";
//	
//	Query.SetParameter("DocumentsArray", RecordsValue.UnloadColumn("ParentDocument"));
//	AcceptanceTable = Query.Execute().Unload();
//	
//	For Each ParentDocumentsRow In RecordsValue Do
//		
//		AcceptanceTableRow = AcceptanceTable.Find(ParentDocumentsRow.ParentDocument, "Document");
//		If AcceptanceTableRow = Undefined Then
//			Continue;
//		EndIf;
//		
//		If ValueIsFilled(AcceptanceTableRow.NextUser) And AcceptanceTableRow.BlockNestedDocuments
//			AND NOT Source.AdditionalProperties.Property("CostOfGoodsSequenceRestoring") Then
//			Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + NStr("en = 'You cann''t post document base on not accepted document'; pl = 'Nie można zatwierdzić dokumentu na podstawie niezaakceptowanego dokumentu'") + ": " + ParentDocumentsRow.ParentDocument, , Cancel, Source);
//		EndIf;
//		
//	EndDo;
//	
//EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH DOCUMENTS ACCEPTANCE

//Procedure DocumentsPostingAcceptancePosting(Source, Cancel, PostingMode) Export
//	
//	If Source.DataExchange.Load = True Then
//		Return;
//	EndIf;	
//	
//	// First check if it has sense to work with acceptance.
//	Query = New Query;
//	Query.Text = "SELECT
//	             |	1 AS Field1
//	             |FROM
//	             |	InformationRegister.DocumentsAcceptanceSettings AS DocumentsAcceptanceSettings
//	             |WHERE
//	             |	DocumentsAcceptanceSettings.DocumentType = &DocumentType
//	             |	AND DocumentsAcceptanceSettings.UseAcceptance";
//	
//	Query.SetParameter("DocumentType", Documents[Source.Metadata().Name].EmptyRef());	
//	QueryResult = Query.Execute();
//	If QueryResult.IsEmpty() Then
//		Return;
//	EndIf;
//	
//	// Get current document's state
//	ErrorMessage = "";
//	SchemaRef = CommonAtServer.DocumentsAcceptance_GetSchemaRef(Source.Ref, ErrorMessage);
//	If SchemaRef = Undefined Then
//		Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + ErrorMessage, , Cancel, Source);
//		Return;
//	EndIf;
//	
//	CurrentStateStructure = DocumentsAcceptance.GetCurrentState(Source.Ref);
//	CurrentUser = SessionParameters.CurrentUser;
//	
//	// Check user's rights to change current schema
//	If ValueIsFilled(CurrentStateStructure) And ValueIsFilled(CurrentStateStructure.Schema) Then
//		
//		CurrentSchemaTable = DocumentsAcceptance.GetSchemaTable(Source.Ref);
//		SchemaTableRow = CurrentSchemaTable.Find(CurrentUser, "User, SubstituteUser");
//		
//		If SchemaTableRow = Undefined And CurrentUser <> Source.Author Then
//			Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + NStr("en = 'You cann''t change this document. You are not in the acceptance schema.'; pl = 'Nie możesz zmienić ten dokument. Nie jesteś w schemacie akceptacji.'"), , Cancel, Source);
//			Return;
//		EndIf;
//		
//	EndIf;
//	
//	Period = GetServerDate();
//	
//	If ValueIsFilled(SchemaRef) Then // need to reaccept the document
//		
//		// Fill acceptance schema if needed
//		If CurrentStateStructure = Undefined Or CurrentStateStructure.Schema <> SchemaRef Then
//			
//			ErrorMessage = "";
//			If Not DocumentsAcceptance.SetAcceptanceSchema(Source.Ref, SchemaRef, ErrorMessage, Period) Then
//				Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + ErrorMessage, , Cancel, Source);
//				Return;
//			EndIf;
//			
//		EndIf;
//		
//		ErrorMessage = "";
//		ReceivedInvoice = Undefined;
//		WasReceivedInvoice = Source.AdditionalProperties.Property("ReceivedInvoice",ReceivedInvoice);
//		If NOT WasReceivedInvoice OR ReceivedInvoice <> True Then
//			If Not DocumentsAcceptance.Accept(Source.Ref, "", ErrorMessage, , Enums.DocumentsAcceptanceActions.Posted) Then
//				Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + ErrorMessage, , Cancel, Source);
//				Return;
//			EndIf;
//		EndIf;
//		
//	Else // clear acceptance schema if needed
//		
//		ErrorMessage = "";
//		If Not DocumentsAcceptance.ClearAcceptanceSchema(Source.Ref, ErrorMessage, CurrentUser, Enums.DocumentsAcceptanceActions.Posted, Period) Then
//			Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + ErrorMessage, , Cancel, Source);
//			Return;
//		EndIf;
//		
//	EndIf;
//	
//EndProcedure

//Procedure DocumentsUndoPostingAcceptanceUndoPosting(Source, Cancel) Export
//	
//	If Source.DataExchange.Load = True Then
//		Return;
//	EndIf;	
//	
//	CurrentStateStructure = DocumentsAcceptance.GetCurrentState(Source.Ref);
//	
//	If ValueIsNotFilled(CurrentStateStructure) Or ValueIsNotFilled(CurrentStateStructure.Schema) Then
//		Return;
//	EndIf;
//	
//	CurrentUser = SessionParameters.CurrentUser;
//	SchemaTable = DocumentsAcceptance.GetSchemaTable(Source.Ref);
//	SchemaTableRow = SchemaTable.Find(CurrentUser, "User, SubstituteUser");
//	
//	If SchemaTableRow = Undefined And CurrentUser <> Source.Author Then
//		Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + NStr("en = 'You cann''t change this document. You are not in the acceptance schema.'; pl = 'Nie możesz zmienić ten dokument. Nie jesteś w schemacie akceptacji.'"), , Cancel, Source);
//		Return;
//	EndIf;
//	
//	Period = GetServerDate();
//	
//	ErrorMessage = "";
//	If Not DocumentsAcceptance.ClearAcceptanceSchema(Source.Ref, ErrorMessage, CurrentUser, Enums.DocumentsAcceptanceActions.UndoPosted, Period) Then
//		Alerts.AddAlert(Source.AdditionalProperties.MessageTitle + " " + ErrorMessage, , Cancel, Source);
//		Return;
//	EndIf;
//	
//EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH EDI TRANSFER

//Procedure SetECODRegistrationPosting(Source, Cancel, PostingMode) Export
//	
//	Company = Source.Company;
//	Date = Source.Date;
//	DocumentType = New(TypeOf(Source.Ref));
//	Customer = Source.Customer;
//	
//	ECODRelation = EDITransaction.GetECODRelation(Company,Customer,Date,DocumentType);
//	
//	If ValueIsFilled(ECODRelation.TransactionType) Then
//		
//		If NOT EDITransaction.IsDocumentCanBeSendViaEdi(Source,ECODRelation,Cancel) Then
//			Return;
//		EndIf;
//		
//				
//		If NOT Cancel Then
//			
//			RecordSet = InformationRegisters.SendingViaEDI.CreateRecordSet();
//			RecordSet.Filter.Period.Set(Date);
//			RecordSet.Filter.Document.Set(Source.Ref);

//			
//			Record = RecordSet.Add();
//			
//			Record.Period = Date;
//			Record.Document = Source.Ref;
//			Record.Status = Enums.EDIDocumentSendingStatuses.NotSent;
//			Record.DocumentRecorder = Source.Ref;
//			
//			Record.Author = Source.Author;
//			Record.Company = Company;
//			Record.Customer = Customer;
//			Record.DocumentType = DocumentType;
//			Record.TransactionType = ECODRelation.TransactionType;
//			
//			RecordSet.SetProgramWriteFlag();
//		
//			RecordSet.Write();	
//			
//			If TypeOf(Source.Ref) = TypeOf(Documents.SalesCreditNoteReturn.EmptyRef()) 
//				OR TypeOf(Source.Ref) = TypeOf(Documents.SalesCreditNotePriceCorrection.EmptyRef()) Then				
//				// Documents subordinate to invoice.
//				EDIStatus = EDITransaction.GetDocumentEDIStatusStructure(Source.SalesInvoice).Status;
//				If EDIStatus = Enums.EDIDocumentSendingStatuses.Cancelled Then
//					Alerts.AddAlert(NStr("en=""This document marked for EDI sending as cancelled, because of document base is also cancelled"";pl=""Ten dokument został oznaczony do wysłania przez EDI jak anulowany, dlatego że dokument podstawa także jest anulowany""")+ " : "+ TrimAll(Source),,,Source);
//					// Document should be created with cancellation.
//					
//					RecordSet = InformationRegisters.SendingViaEDI.CreateRecordSet();
//					RecordSet.Filter.Period.Set(Date + 1);
//					RecordSet.Filter.Document.Set(Source.Ref);
//					
//					Record = RecordSet.Add();
//					
//					Record.Period = Date + 1; // increase Date
//					Record.Document = Source.Ref;
//					Record.Status = Enums.EDIDocumentSendingStatuses.Cancelled;
//					
//					Record.Author = Source.Author;
//					Record.Company = Company;
//					Record.Customer = Customer;
//					Record.DocumentType = DocumentType;
//					Record.TransactionType = ECODRelation.TransactionType;
//					
//					RecordSet.SetProgramWriteFlag();
//					
//					RecordSet.Write();	

//				EndIf;	
//				
//			EndIf;
//						
//		EndIf;
//				
//	EndIf;	
//	
//EndProcedure

//Procedure CancelECODRegistrationUndoPosting(Source, Cancel) Export
//	
//	If NOT Cancel Then
//		
//		RecordSet = InformationRegisters.SendingViaEDI.CreateRecordSet();
//		RecordSet.Filter.Period.Set(Source.Date);
//		RecordSet.Filter.Document.Set(Source.Ref);
//		
//		For Each Record In RecordSet Do
//			If Record.DocumentRecorder = Source.Ref Then
//				Index = RecordSet.IndexOf(Record);
//				RecordSet.Delete(Index);
//			EndIf;	
//		EndDo;	
//		
//		RecordSet.SetProgramWriteFlag();
//		
//		RecordSet.Write();
//		
//	EndIf;
//	
//EndProcedure

//Procedure DocumentsOnWriteCheckSendToEDI(Source, Cancel) Export
//	
//	If (Not Source.AdditionalProperties.Property("CostOfGoodsSequenceRestoring")
//		And Source.AdditionalProperties.WriteMode = DocumentWriteMode.Posting)
//		OR Source.AdditionalProperties.WriteMode = DocumentWriteMode.UndoPosting Then
//		
//		Query = New Query();
//		Query.Text = "SELECT
//		             |	TRUE AS Field1
//		             |FROM
//		             |	InformationRegister.SendingViaEDI.SliceLast(
//		             |			,
//		             |			Document = &Ref
//		             |				AND TransactionType = VALUE(Enum.ECODTransactionTypes.Production)) AS SendingViaEDISliceLast
//		             |WHERE
//		             |	SendingViaEDISliceLast.Status IN (VALUE(Enum.EDIDocumentSendingStatuses.Committed), VALUE(Enum.EDIDocumentSendingStatuses.Sent))";
//		
//		Query.SetParameter("Ref",Source.Ref);
//		
//		Selection = Query.Execute().Select();

//		If Selection.Next() Then
//			
//			Alerts.AddAlert(NStr("en=""This document was already sent to EDI and can not be changed"";pl=""Ten dokument został już wysłany przez EDI i nie może być zmieniony""")+ " : "+ TrimAll(Source),,Cancel,Source);
//			
//			Return;
//			
//		EndIf;
//		
//	EndIf;
//	
//EndProcedure

//Procedure CatalogsBeforeWriteAllBeforeWrite(Source, Cancel) Export
//		
//	Alerts.ClearAlertsTable(Source);
//	Source.AdditionalProperties.Insert("WritingProcess");
//	
//	If Not Source.DataExchange.Load Then
//		LanguagesModulesServer.SetSystemLanguageDescription(Source);
//	EndIf;
//	
//EndProcedure

//Procedure DocumentsCostOfGoodsBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
//	
//	If Not Source.IsNew() AND Source.Posted = True
//		AND PostingMode = DocumentPostingMode.RealTime Then
//		PostingMode = DocumentPostingMode.Regular;
//		Source.AdditionalProperties.Insert("DisableRealTimePosting", True);
//		Alerts.AddAlert(Nstr("en = 'Current document could not be posted in operational mode, because it has influence on cost of goods. If you want to change date of document, please, do it manually.'; pl = 'Ten dokument nie może być zatwierdzony w trybie operatywnym, ponieważ ma on wpływ na koszty towarów. Jeśli chcesz zmienić datę dokumentu, należy to zrobić ręcznie.'"),Enums.AlertType.Warning);
//	EndIf;	
//	
//	If WriteMode = DocumentWriteMode.UndoPosting Then
//		Source.AdditionalProperties.Insert("DisableRealTimePosting", True);
//	EndIf;	
//	
//EndProcedure

Procedure DocumentsOnCopyOnCopy(Source, CopiedObject) Export
	If CommonAtServer.IsDocumentAttribute("VATDate", Source.Metadata()) Then
		Source["VATDate"] = '00010101';
	EndIf;
	If CommonAtServer.IsDocumentAttribute("SalesDate", Source.Metadata()) Then
		Source["SalesDate"] = '00010101';
	EndIf;
	If CommonAtServer.IsDocumentAttribute("Author", Source.Metadata()) Then
		Source["Author"] = SessionParameters.CurrentUser;
	EndIf;
	If CommonAtServer.IsDocumentAttribute("Prefix", Source.Metadata()) Then
		Source["Prefix"] = "";
	EndIf;
	If CommonAtServer.IsDocumentAttribute("ManualChangeNumber", Source.Metadata()) Then
		Source["ManualChangeNumber"] = False;
	EndIf;
EndProcedure

Procedure CatalogsOnCopyOnCopy(Source, CopiedObject) Export
	If CommonAtServer.IsDocumentAttribute("Author", Source.Metadata()) Then
		Source["Author"] = SessionParameters.CurrentUser;
	EndIf;
	If CommonAtServer.IsDocumentAttribute("Date", Source.Metadata()) Then
		Source["Date"] = GetServerDate();
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PROCEDURES AND FUNCTIONS WORKING WITH CATALOGS

Procedure CatalogsOnWrite(Source, Cancel) Export
	
	If Not Cancel then
		AdditionalAttributesServer.WrireAdditionalAttributeValues(Source);
	EndIf;	 	
	
EndProcedure

Procedure DocumentsFillingAllFilling(Source, FillingData, StandardProcessing) Export
	If CommonAtServer.IsDocumentAttribute("Author", Source.Metadata()) Then
		Source["Author"] = SessionParameters.CurrentUser;
	EndIf;
EndProcedure
