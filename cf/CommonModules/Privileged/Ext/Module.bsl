
Function IsUserHasWindowsAuthorization(Val InfobaseUserName) Export
	
	If IsBlankString(InfobaseUserName) Then
		Return False;
	EndIf;
	
	
	InfobaseUser = InfoBaseUsers.FindByName(InfobaseUserName);
	If InfobaseUser = Undefined Then
		Return False;
	EndIf;
	
	Return InfobaseUser.OSAuthentication;
	
EndFunction

Function GetNotEmptyRecordSetsNames(Ref) Export
	
	Array = New Array;
	
	RefMetadata = Ref.Metadata();
	
	If RefMetadata.RegisterRecords.Count() = 0 Then
		Return Array;
	EndIf;
	
	QueryText = "";
	For Each RecordSetMetadata In RefMetadata.RegisterRecords Do
		
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + "
			                        |
			                        |UNION ALL
			                        |
			                        |";
		EndIf;
		
		QueryText = QueryText + "SELECT TOP 1
		                        |	""" + RecordSetMetadata.Name + """ AS Name
		                        |FROM
		                        |	" + RecordSetMetadata.FullName() + " AS Register
		                        |WHERE
		                        |	Register.Recorder = &Recorder";
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", Ref);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Array.Add(Selection.Name);
	EndDo;
	
	Return Array;
	
EndFunction

//////////////////////////////////////////////////////////////////////
//// EDI Transactions


// Jack 29.05.2017
//Function GetECODAuthentication(Company)
//	
//	Return InformationRegisters.EDISettings.Get(New Structure("Company, Provider",Company,Enums.EDIProviders.ECOD));
//	
//EndFunction	

//Function SendEDIXML(Company, Customer, XMLContent, DocumentTypeName, TransactionTypeName, ECODVersionName) Export
//		
//	ECODAuthentication = GetECODAuthentication(Company);
//	
//	Proxy = WSReferences.ECODWSReference.CreateWSProxy("http://www.comarch.com/", "EDIService", "EDIServiceSoap");
//			
//	Result = Proxy.Send(ECODAuthentication.Login, ECODAuthentication.Password, Customer.ILN, DocumentTypeName, ECODVersionName, "XML", TransactionTypeName, 0, XMLContent, 1000);
//	
//	If Result.Res <> EDITransaction.GetEDISuccessReturnCode() Then
//		
//		Return Undefined;
//		
//	Else	
//		
//		Return Result.Cnt;
//		
//	EndIf;	
//	
//EndFunction

//// returns XML with avaliable documents
//Function GetEDIListMB(Company, CustomerILN, ECODDocumentType,ECODVersion,TransactionTypeName = "T",DocumentStatus = "N") Export
//	
//	ECODAuthentication = GetECODAuthentication(Company);
//	
//	Proxy = WSReferences.ECODWSReference.CreateWSProxy("http://www.comarch.com/", "EDIService", "EDIServiceSoap");
//	
//	Result = Proxy.ListMB(ECODAuthentication.Login, ECODAuthentication.Password, CustomerILN, ECODDocumentType, ECODVersion, "XML", TransactionTypeName, DocumentStatus, 10000);
//	
//		
//	If Result.Res <> EDITransaction.GetEDISuccessReturnCode() Then
//		Return "";
//	Else	
//		Return Result.Cnt;
//	EndIf;	

//EndFunction	

//// Returns XML with document content
//Function ReceiveEDIXML(Company, CustomerILN,DocumentHandle,DocumentType,DocumentStatus="N") Export
//	
//	ECODAuthentication = GetECODAuthentication(Company);
//	
//	Proxy = WSReferences.ECODWSReference.CreateWSProxy("http://www.comarch.com/", "EDIService", "EDIServiceSoap");
//	
//	Result = Proxy.Receive(ECODAuthentication.Login, ECODAuthentication.Password, CustomerILN, DocumentType, DocumentHandle, "XML", DocumentStatus, 5000); // Don't change document status
//				
//	If Result.Res <> EDITransaction.GetEDISuccessReturnCode() Then
//		Return "";
//	Else	
//		Return Result.Cnt;
//	EndIf;	
//	
//EndFunction	

//Function GetRelationsEDIXML(Company) Export
//	
//	ECODAuthentication = GetECODAuthentication(Company);
//	
//	Proxy = WSReferences.ECODWSReference.CreateWSProxy("http://www.comarch.com/", "EDIService", "EDIServiceSoap");
//	
//	ReceiveResult = Proxy.Relationships(ECODAuthentication.Login, ECODAuthentication.Password, 5000);
//	
//	If ReceiveResult.Res <> EDITransaction.GetEDISuccessReturnCode() Then
//		Return "";
//	Else	
//		Return ReceiveResult.Cnt;	
//	EndIf;	
//	
//EndFunction	

//// returns XML with avaliable documents
//// getting list by hundret
//Function GetEDIListPB(Company, CustomerILN,DocumentTypeName, ECODVersion,TransactionTypeName,PeriodStart=Undefined,PeriodEnd=Undefined,NumberOfHundret = 0) Export
//	
//	ECODAuthentication = GetECODAuthentication(Company);
//	
//	Proxy = WSReferences.ECODWSReference.CreateWSProxy("http://www.comarch.com/", "EDIService", "EDIServiceSoap");
//	
//	If PeriodStart = Undefined AND PeriodEnd = Undefined Then
//		Result = Proxy.ListPB(ECODAuthentication.Login, ECODAuthentication.Password, CustomerILN, DocumentTypeName, ECODVersion, "XML", TransactionTypeName,,,NumberOfHundret*100 + 1,(NumberOfHundret+1)*100,1000);
//	ElsIf PeriodStart = Undefined AND PeriodEnd <> Undefined Then	
//		Result = Proxy.ListPB(ECODAuthentication.Login, ECODAuthentication.Password, CustomerILN, DocumentTypeName, ECODVersion, "XML", TransactionTypeName,,Format(PeriodEnd, EDITransaction.GetEDIDateFormatString()),NumberOfHundret*100 + 1,(NumberOfHundret+1)*100,1000);
//	ElsIf PeriodStart <> Undefined AND PeriodEnd = Undefined Then	
//		Result = Proxy.ListPB(ECODAuthentication.Login, ECODAuthentication.Password, CustomerILN, DocumentTypeName, ECODVersion, "XML", TransactionTypeName,Format(PeriodStart, EDITransaction.GetEDIDateFormatString()),,NumberOfHundret*100 + 1,(NumberOfHundret+1)*100,1000);
//	Else
//		Result = Proxy.ListPB(ECODAuthentication.Login, ECODAuthentication.Password, CustomerILN, DocumentTypeName, ECODVersion, "XML", TransactionTypeName,Format(PeriodStart, EDITransaction.GetEDIDateFormatString()),Format(PeriodEnd, EDITransaction.GetEDIDateFormatString()),NumberOfHundret*100 + 1,(NumberOfHundret+1)*100,1000);
//	EndIf;
//	
//	If Result.Res <> EDITransaction.GetEDISuccessReturnCode() Then
//		Return "";
//	Else	
//		NumberOfHundret = NumberOfHundret + 1;
//		Return Result.Cnt;
//	EndIf;	

//EndFunction	

//Function ChangeDocumentEDIStatus(Company,DocumentHandle,NewStatus) Export
//	
//	ECODAuthentication = GetECODAuthentication(Company);
//	
//	Proxy = WSReferences.ECODWSReference.CreateWSProxy("http://www.comarch.com/", "EDIService", "EDIServiceSoap");
//	
//	ReceiveResult = Proxy.ChangeDocumentStatus(ECODAuthentication.Login, ECODAuthentication.Password,DocumentHandle, NewStatus);
//	
//	If ReceiveResult.Res <> EDITransaction.GetEDISuccessReturnCode() Then
//		Return "";
//	Else	
//		Return ReceiveResult.Cnt;	
//	EndIf;	

//	
//EndFunction	

//Procedure WriteECODRECADVItem(EDIID,Customer,Date,ReceivingAdviceNumber,SalesOrderNumber,DespatchNumber) Export
//	
//	RecordManager = InformationRegisters.ECODRECADV.CreateRecordManager();
//	RecordManager.EDIID = EDIID;
//	RecordManager.Read();
//	If NOT RecordManager.Selected() Then
//		RecordManager.EDIID = EDIID;
//	EndIf;	
//	RecordManager.Customer = Customer;
//	RecordManager.Date = Date;
//	RecordManager.ReceivingAdviceNumber = ReceivingAdviceNumber;
//	RecordManager.SalesOrderNumber = SalesOrderNumber;
//	RecordManager.DespatchNumber = TrimAll(DespatchNumber);
//	RecordManager.Write();
//	
//EndProcedure	


//////////////////////////////////////////////////////////////////////
//// Fiscalization

//Function SetDocumentFiscalization(Document) Export
//	
//	RecordManager = InformationRegisters.FiscaledDocuments.CreateRecordManager();
//	RecordManager.Document = Document;
//	RecordManager.Read();
//	RecordManager.Document = Document;
//	RecordManager.DateOfFiscalization = CurrentDate();
//	RecordManager.Author = SessionParameters.CurrentUser;
//	RecordManager.Write();
//	
//EndFunction	

////////////////////////////////////////////////////////////////////
// Bookkeeping posting

Procedure BookkeepingOperationOnWriteProcessing(Ref,DocumentBaseRef,Cancel) Export
	
	If ValueIsNotFilled(DocumentBaseRef) Then
		Return;
	EndIf;	
	
	SelectionStructure = GetBookkeepingOperationsSelection(DocumentBaseRef,Ref);
	
	If SelectionStructure <> Undefined Then
		
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='An error occurred during writing Bookkeeping operation for document %P1. Document already has bookkeeping operation %P2!';pl='Powstał błąd podczas zapisywania dowódu księgowego dla dokumentu %P1. Dokument już ma dowód księgowy %P2!'"),New Structure("P1,P2",Ref,SelectionStructure.Ref)),Enums.AlertType.Error,Cancel);
		
	EndIf;		
	
EndProcedure	

Function DocumentBookkeepingPostingProcessing(BookkeepingPostingType, SourceRef, IsCostOfGoodsSequenceRestoring, DocumentBecamePosted, Cancel, IsAutoLock = False) Export
	
	ReturnStructure = New Structure("Status, Details",Enums.DocumentBookkeepingStatus.NotBookkeepingPosted,Undefined);
	
	SelectionStructure = GetBookkeepingOperationsSelection(SourceRef,Documents.BookkeepingOperation.EmptyRef());
	
	If SelectionStructure = Undefined Then
		// Check Auto
		If BookkeepingPostingType = Enums.BookkeepingPostingTypes.OnPosting Then
			// Create new bookkeeping operation
			RetRecommendedSchema = Undefined;
			RetCounter = BookkeepingCommon.GetRecommendSchemaForDocument(SourceRef,RetRecommendedSchema);
			
			If RetCounter = 1 Then
				BookkeepingOperationObject = Documents.BookkeepingOperation.CreateDocument();
				BookkeepingOperationObject.Author = SessionParameters.CurrentUser;
				BookkeepingOperationObject.FillingOnDocumentBaseAndTemplate(SourceRef,RetRecommendedSchema);
				BookkeepingOperationObject.SetNewNumber();
				BookkeepingOperationsTemplateObject = RetRecommendedSchema.GetObject();
				// Setting company and other attributes
				BookkeepingOperationsTemplateObject.FillBookkeepingDocument(SourceRef,BookkeepingOperationObject);
				// Should be after setting company
				BookkeepingOperationObject.AdditionalProperties.Insert("IsAutoLock",IsAutoLock);
				BookkeepingOperationObject.Write(DocumentWriteMode.Posting);
				
				ReturnStructure.Insert("Status",Enums.DocumentBookkeepingStatus.BookkeepingPosted);
				
			ElsIf RetCounter = 0 Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='Bookkeeping operation for document %P1 was not created automatically because was no found matching schemas for this document. Bookkeeping operation should be created and posted manually!';pl='Dowód księgowy dla dokumentu %P1 nie został stworzony automatyczne dlatego że nie został odnaleziony schemat księgowania dla tego dokumentu. DK ma być stworzony i zaksięgowany ręcznie!'"),New Structure("P1",SourceRef)),Enums.AlertType.Warning);
			ElsIf RetCounter > 1 Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en='Bookkeeping operation for document %P1 was not created automatically because was found more than one matching schemas for this document. Bookkeeping operation should be created and posted manually!';pl='Dowód księgowy dla dokumentu %P1 nie został stworzony automatyczne dlatego że zostało odnalezione wielie schematów księgowania dla tego dokumentu. DK ma być stworzony i zaksięgowany ręcznie!'"),New Structure("P1",SourceRef)),Enums.AlertType.Warning);
			EndIf;	
		EndIf;	
		
	Else
		If SelectionStructure.Posted OR DocumentBecamePosted Then
			BookkeepingOperationObject = SelectionStructure.Ref.GetObject();
			If SelectionStructure.Manual Then
				NotificationsArray = New Array;
				NotificationsArray.Add(Enums.NotificationEvents.BookkepingOperationWithManualChangesUnposting);
				If IsCostOfGoodsSequenceRestoring Then
					NotificationsArray.Add(Enums.NotificationEvents.BookkepingOperationUnpostingOnCostOfGoodsSequenceRestoring);
				EndIf;	
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Document with manual changes was unposted: %P1'; pl = 'Dokument z ręcznymi zmianami został odksięgowany: %P1'"),New Structure("P1",SelectionStructure.Ref)),Enums.AlertType.Warning,,SourceRef,SourceRef,NotificationsArray);
				BookkeepingOperationObject.AdditionalProperties.Insert("IsAutoLock",IsAutoLock);
				BookkeepingOperationObject.Write(DocumentWriteMode.UndoPosting);
			Else
				// Regenerate
				BookkeepingOperationsTemplateObject = BookkeepingOperationObject.BookkeepingOperationsTemplate.GetObject();
				// Setting company and other attributes
				BookkeepingOperationObject.FillingOnDocumentBaseAndTemplate(SourceRef,BookkeepingOperationObject.BookkeepingOperationsTemplate);
				BookkeepingOperationsTemplateObject.FillBookkeepingDocument(SourceRef,BookkeepingOperationObject);
				BookkeepingOperationObject.DeletionMark = False;
				BookkeepingOperationObject.AdditionalProperties.Insert("IsAutoLock",IsAutoLock);
				WasError = False;
				Try
					BookkeepingOperationObject.Write(DocumentWriteMode.Posting);
				Except
					WasError = True;
					If IsCostOfGoodsSequenceRestoring Then
						ReturnStructure.Insert("Details",SelectionStructure.Ref);
					Else
						Raise ErrorDescription();
					EndIf;
				EndTry;	
				If NOT WasError Then	
					ReturnStructure.Insert("Status",Enums.DocumentBookkeepingStatus.BookkeepingPosted);
				EndIf;	
			EndIf;	
		EndIf;
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

Procedure DocumentBookkeepingUndoPostingProcessing(SourceRef, IsAutoLock = False) Export
	
	SelectionStructure = GetBookkeepingOperationsSelection(SourceRef,Documents.BookkeepingOperation.EmptyRef());
	
	If SelectionStructure <> Undefined Then
		
		If SelectionStructure.Posted Then
			
			Object = SelectionStructure.Ref.GetObject();
			Object.AdditionalProperties.Insert("IsAutoLock",IsAutoLock);
			Object.DeletionMark = True;
			Object.Write(DocumentWriteMode.UndoPosting);
			
		Else
			
			If NOT SelectionStructure.DeletionMark Then
				
				Object = SelectionStructure.Ref.GetObject();
				Object.AdditionalProperties.Insert("IsAutoLock",IsAutoLock);
				Object.DeletionMark = True;
				Object.Write();
				
			EndIf;	
			
		EndIf;	
		
	EndIf;	
	
EndProcedure	

Function GetBookkeepingOperationsSelection(DocumentBaseRef, OwnRef) 
	
	Query = New Query;
	
	Query.Text = "SELECT TOP 1
	             |	BookkeepingOperation.Ref AS Ref,
	             |	BookkeepingOperation.DeletionMark AS DeletionMark,
	             |	BookkeepingOperation.Posted AS Posted,
	             |	BookkeepingOperation.Manual AS Manual
	             |FROM
	             |	Document.BookkeepingOperation AS BookkeepingOperation
	             |WHERE
	             |	BookkeepingOperation.DocumentBase = &DocumentBase
	             |	AND BookkeepingOperation.Ref <> &OwnRef";
	
	Query.SetParameter("DocumentBase",DocumentBaseRef);
	Query.SetParameter("OwnRef",OwnRef);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		SelectionStructure = New Structure;
		SelectionStructure.Insert("Ref",Selection.Ref);
		SelectionStructure.Insert("DeletionMark",Selection.DeletionMark);
		SelectionStructure.Insert("Posted",Selection.Posted);
		SelectionStructure.Insert("Manual",Selection.Manual);
		Return SelectionStructure;
	Else
		Return Undefined;
	EndIf;	
	
EndFunction	

////////////////////////////////////////////////////////////////////
// CHECK OBJECTS

Function NeedToCheckCatalogInDocuments(AttributesToCheckStructure, Ref) Export
	
	NeedToCheck = False;
	If Ref.IsEmpty() Then
		NeedToCheck = False;
	ElsIf Ref.IsFolder Then
		NeedToCheck = False;
	ElsIf AttributesToCheckStructure.Count() = 0 Then
		NeedToCheck = True; // Cann't be modified at all
	Else
		For Each KeyAndValue In AttributesToCheckStructure Do
			If Ref[KeyAndValue.Key] <> KeyAndValue.Value Then
				NeedToCheck = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return NeedToCheck;
	
EndFunction

Procedure IsCatalogInPostedDocuments(AttributesToCheckStructure, AdditionalCatalogsStructure = Undefined, Ref, Cancel) Export
	
	If Not NeedToCheckCatalogInDocuments(AttributesToCheckStructure, Ref) Then
		Return;
	EndIf;
	
	If AdditionalCatalogsStructure = Undefined Then
		AdditionalCatalogsStructure = New Structure;
	EndIf;
	
	MainType = TypeOf(Ref);
	AdditionalTypes = New Map;
	For Each KeyAndValue In AdditionalCatalogsStructure Do
		AdditionalTypes.Insert(Type("CatalogRef." + KeyAndValue.Key), KeyAndValue.Key + "TempTable");
	EndDo;
	
	DocumentsTable = New ValueTable;
	DocumentsTable.Columns.Add("DocumentName");
	DocumentsTable.Columns.Add("AttributesMap");
	
	TabularSectionsTable = New ValueTable;
	TabularSectionsTable.Columns.Add("TabularSectionName");
	TabularSectionsTable.Columns.Add("AttributesMap");
	
	For Each MetadataDocument In Metadata.Documents Do
		
		AttributesMap = New Map;
		
		// Attributes check
		For Each Attribute In MetadataDocument.Attributes Do
			
			If Attribute.Type.ContainsType(MainType) Then
				AttributesMap.Insert(Attribute.Name, "&Ref");
			EndIf;
			
			For Each KeyAndValue In AdditionalTypes Do
				If Attribute.Type.ContainsType(KeyAndValue.Key) Then
					AttributesMap.Insert(Attribute.Name, KeyAndValue.Value);
				EndIf;
			EndDo;
			
		EndDo;
		
		// Tabular sections check
		TabularSectionsTable.Clear();
		For Each TabularSection In MetadataDocument.TabularSections Do
			
			TabularSectionAttributesMap = New Map;
			For Each Attribute In TabularSection.Attributes Do
				
				If Attribute.Type.ContainsType(MainType) Then
					TabularSectionAttributesMap.Insert(Attribute.Name, "&Ref");
				EndIf;
				
				For Each KeyAndValue In AdditionalTypes Do
					If Attribute.Type.ContainsType(KeyAndValue.Key) Then
						TabularSectionAttributesMap.Insert(Attribute.Name, KeyAndValue.Value);
					EndIf;
				EndDo;
				
			EndDo;
			
			If TabularSectionAttributesMap.Count() > 0 Then
				TabularSectionsTableRow = TabularSectionsTable.Add();
				TabularSectionsTableRow.TabularSectionName = TabularSection.Name;
				TabularSectionsTableRow.AttributesMap = TabularSectionAttributesMap;
			EndIf;
			
		EndDo;
		
		// Add rows to documents table
		If AttributesMap.Count() > 0 Or TabularSectionsTable.Count() > 0 Then
			
			If TabularSectionsTable.Count() > 0 Then
				For Each KeyAndValue In TabularSectionsTable[0].AttributesMap Do
					AttributesMap.Insert(TabularSectionsTable[0].TabularSectionName + "." + KeyAndValue.Key, KeyAndValue.Value);
				EndDo;
			EndIf;
			
			DocumentsTableRow = DocumentsTable.Add();
			DocumentsTableRow.DocumentName = MetadataDocument.Name;
			DocumentsTableRow.AttributesMap = AttributesMap;
			
			For Each TabularSectionsTableRow In TabularSectionsTable Do
				
				If TabularSectionsTable.IndexOf(TabularSectionsTableRow) = 0 Then
					Continue;
				EndIf;
				
				AttributesMap = New Map;
				For Each KeyAndValue In TabularSectionsTableRow.AttributesMap Do
					AttributesMap.Insert(TabularSectionsTableRow.TabularSectionName + "." + KeyAndValue.Key, KeyAndValue.Value);
				EndDo;
				
				DocumentsTableRow = DocumentsTable.Add();
				DocumentsTableRow.DocumentName = MetadataDocument.Name;
				DocumentsTableRow.AttributesMap = AttributesMap;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If DocumentsTable.Count() = 0 Then
		Return;
	EndIf;
	
	// Create queries for temp tables
	TempTablesQeriesText = "";
	TempTablesConditionsStructure = New Structure;
	For Each KeyAndValue In AdditionalCatalogsStructure Do
		
		TempTableName = KeyAndValue.Key + "TempTable";
		
		ConditionText = "";
		If TypeOf(KeyAndValue.Value) = Type("String") Then
			ConditionText = KeyAndValue.Key + "." + KeyAndValue.Value + " = &Ref";
		ElsIf TypeOf(KeyAndValue.Value) = Type("Array") Then
			For Each AttributePath In KeyAndValue.Value Do
				ConditionText = ConditionText + Chars.LF + "			OR " + KeyAndValue.Key + "." + AttributePath + " = &Ref";
			EndDo;
			ConditionText = Right(ConditionText, StrLen(ConditionText) - 7);
		Else
			Cancel = True;
			Raise NStr("en = 'Wrong parameter type for additional catalogs attributes.'; pl = 'Błędny typ parametru dla atrybutów dodatkowych katalogów.'");
		EndIf;
		
		TempTablesQeriesText = TempTablesQeriesText + "SELECT
		                                              |	" + KeyAndValue.Key + ".Ref
		                                              |INTO " + TempTableName + "
		                                              |FROM
		                                              |	Catalog." + KeyAndValue.Key + " AS " + KeyAndValue.Key + "
		                                              |WHERE
		                                              |	" + ConditionText + "
		                                              |;
		                                              |
		                                              |////////////////////////////////////////////////////////////////////////////////
		                                              |";
		
		TempTableConditionText = "
		                         |					(SELECT
		                         |						TempTable.Ref
		                         |					FROM
		                         |						" + TempTableName + " AS TempTable)";
		
		TempTablesConditionsStructure.Insert(TempTableName, TempTableConditionText);
		
	EndDo;
	
	NestedQueryText = "";
	For Each DocumentsTableRow In DocumentsTable Do
		
		TableAlias = DocumentsTableRow.DocumentName + DocumentsTable.IndexOf(DocumentsTableRow);
		
		ConditionText = "";
		For Each KeyAndValue In DocumentsTableRow.AttributesMap Do
			If KeyAndValue.Value = "&Ref" Then
				ConditionText = ConditionText + Chars.LF + "				OR " + TableAlias + "." + KeyAndValue.Key + " = &Ref";
			Else
				ConditionText = ConditionText + Chars.LF + "				OR " + TableAlias + "." + KeyAndValue.Key + " IN " + TempTablesConditionsStructure[KeyAndValue.Value];
			EndIf;
		EndDo;
		ConditionText = Right(ConditionText, StrLen(ConditionText) - 8);
		
		NestedQueryText = NestedQueryText + "
		                                    |
		                                    |	UNION ALL
		                                    |
		                                    |	SELECT TOP 1
		                                    |		1 AS Field1
		                                    |	FROM
		                                    |		Document." + DocumentsTableRow.DocumentName + " AS " + TableAlias + "
		                                    |	WHERE
		                                    |		" + TableAlias + ".Posted = TRUE
		                                    |		AND (" + ConditionText + ")";
		
	EndDo;
	
	NestedQueryText = Right(NestedQueryText, StrLen(NestedQueryText) - 15);
	
	Query = New Query;
	Query.Text = TempTablesQeriesText + "SELECT TOP 1
	                                    |	1 AS Field1
	                                    |FROM
	                                    |	(" + NestedQueryText + ") AS NestedQuery";
	
	Query.SetParameter("Ref", Ref);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		AlertText = NStr("en = 'There are posted documents with this element in the infobase. Undo posting documents before changing this element.'; pl = 'Są zatwierdzone dokumenty z tym elementem w bazie informacyjnej. Anuluj zatwierdzenie dokumentów przed dokonywaniem zmian.'");
		If AttributesToCheckStructure.Count() > 0 Then
			AlertText = AlertText + Chars.LF + NStr("en=""You cann't change following attributes:"";pl='Nie można zmieniać następujących atrybutów:';ru='Невозможно изменить следующие атрибуты:'");
			MetadataAttributes = Ref.Metadata().Attributes;
			For Each KeyAndValue In AttributesToCheckStructure Do
				AlertText = AlertText + Chars.LF + Chars.Tab + MetadataAttributes[KeyAndValue.Key].Synonym;
			EndDo;
		EndIf;
		
		Alerts.AddAlert(AlertText, Enums.AlertType.Error, Cancel, Ref);
		
	EndIf;
	
EndProcedure

Procedure IsCatalogInPostedDocuments_ForUoM(UoMArray, Ref, Cancel) Export
	
	NeedToCheck = False;
	If Ref.IsEmpty() Then
		NeedToCheck = False;
	ElsIf Ref.IsFolder Then
		NeedToCheck = False;
	ElsIf UoMArray.Count() = 0 Then
		NeedToCheck = False;
	Else
		NeedToCheck = True;
	EndIf;
	
	If Not NeedToCheck Then
		Return;
	EndIf;
	
	MainType = TypeOf(Ref);
	SecondType = Type("CatalogRef.UnitsOfMeasure");
	
	DocumentsTable = New ValueTable;
	DocumentsTable.Columns.Add("DocumentName");
	DocumentsTable.Columns.Add("MainAttributesArray");
	DocumentsTable.Columns.Add("SecondAttributesArray");
	
	TabularSectionsTable = New ValueTable;
	TabularSectionsTable.Columns.Add("TabularSectionName");
	TabularSectionsTable.Columns.Add("MainAttributesArray");
	TabularSectionsTable.Columns.Add("SecondAttributesArray");
	
	For Each MetadataDocument In Metadata.Documents Do
		
		MainAttributesArray = New Array;
		SecondAttributesArray = New Array;
		
		// Attributes check
		For Each Attribute In MetadataDocument.Attributes Do
			
			If Attribute.Type.ContainsType(MainType) And SecondAttributesArray.Find(Attribute.Name) = Undefined Then
				MainAttributesArray.Add(Attribute.Name);
			EndIf;
			If Attribute.Type.ContainsType(SecondType) And MainAttributesArray.Find(Attribute.Name) = Undefined Then
				SecondAttributesArray.Add(Attribute.Name);
			EndIf;
			
		EndDo;
		
		If MainAttributesArray.Count() > 0 And SecondAttributesArray.Count() > 0 Then
			
			DocumentsTableRow = DocumentsTable.Add();
			DocumentsTableRow.DocumentName = MetadataDocument.Name;
			DocumentsTableRow.MainAttributesArray = MainAttributesArray;
			DocumentsTableRow.SecondAttributesArray = SecondAttributesArray;
			
		EndIf;
		
		// Tabular sections check
		TabularSectionsTable.Clear();
		For Each TabularSection In MetadataDocument.TabularSections Do
			
			TabularSectionMainAttributesArray = New Array;
			TabularSectionSecondAttributesArray = New Array;
			For Each Attribute In TabularSection.Attributes Do
				
				If Attribute.Type.ContainsType(MainType) And TabularSectionSecondAttributesArray.Find(Attribute.Name) = Undefined Then
					TabularSectionMainAttributesArray.Add(Attribute.Name);
				EndIf;
				If Attribute.Type.ContainsType(SecondType) And TabularSectionMainAttributesArray.Find(Attribute.Name) = Undefined Then
					TabularSectionSecondAttributesArray.Add(Attribute.Name);
				EndIf;
				
			EndDo;
			
			If TabularSectionMainAttributesArray.Count() > 0 And TabularSectionSecondAttributesArray.Count() > 0 Then
				
				DocumentsTableRow = DocumentsTable.Add();
				DocumentsTableRow.DocumentName = MetadataDocument.Name + "." + TabularSection.Name;
				DocumentsTableRow.MainAttributesArray = TabularSectionMainAttributesArray;
				DocumentsTableRow.SecondAttributesArray = TabularSectionSecondAttributesArray;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If DocumentsTable.Count() = 0 Then
		Return;
	EndIf;
	
	NestedQueryText = "";
	For Each DocumentsTableRow In DocumentsTable Do
		
		DocumentName = DocumentsTableRow.DocumentName;
		
		ConditionText = "";
		For Each AttributeName In DocumentsTableRow.MainAttributesArray Do
			ConditionText = ConditionText + Chars.LF + "				OR " + StrReplace(DocumentName, ".", "") + "." + AttributeName + " = &Ref";
		EndDo;
		ConditionText = Right(ConditionText, StrLen(ConditionText) - 8);
		ConditionText = "AND (" + ConditionText + ")";
		
		SecondConditionText = "";
		For Each AttributeName In DocumentsTableRow.SecondAttributesArray Do
			SecondConditionText = SecondConditionText + Chars.LF + "				OR " + StrReplace(DocumentName, ".", "") + "." + AttributeName + " IN (&UoMArray)";
		EndDo;
		SecondConditionText = Right(SecondConditionText, StrLen(SecondConditionText) - 8);
		SecondConditionText = "AND (" + SecondConditionText + ")";
		ConditionText = ConditionText + Chars.LF + "		" + SecondConditionText;
		
		NestedQueryText = NestedQueryText + "
		                                    |
		                                    |	UNION ALL
		                                    |
		                                    |	SELECT TOP 1
		                                    |		1 AS Field1
		                                    |	FROM
		                                    |		Document." + DocumentName + " AS " + StrReplace(DocumentName, ".", "") + "
		                                    |	WHERE
		                                    |		" + StrReplace(DocumentName, ".", "") + ".Ref.Posted = TRUE
		                                    |		" + ConditionText;
		
	EndDo;
	
	NestedQueryText = Right(NestedQueryText, StrLen(NestedQueryText) - 15);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	1 AS Field1
	             |FROM
	             |	(" + NestedQueryText + ") AS NestedQuery";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("UoMArray", UoMArray);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		AlertText = NStr("en = 'There are posted documents with this element in the infobase. Undo posting documents before changing this element.'; pl = 'Są zatwierdzone dokumenty z tym elementem w bazie informacyjnej. Anuluj zatwierdzenie dokumentów przed dokonywaniem zmian.'");
		AlertText = AlertText + Chars.LF + NStr("en = 'You cann''t change following units of measure:'; pl = 'Nie można zmieniać następujących jednostek miary:'");
		For Each UoM In UoMArray Do
			AlertText = AlertText + Chars.LF + Chars.Tab + UoM;
		EndDo;
		
		Alerts.AddAlert(AlertText, Enums.AlertType.Error, Cancel, Ref);
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///// Payment reminders

// Jack 29.05.2017
//Procedure SetPaymentReminder(Document,PaymentReminder) Export
//	
//	ServerDate = GetServerDate();
//	CurrentUser = SessionParameters.CurrentUser;
//	RecordSet = InformationRegisters.SentPaymentReminders.CreateRecordSet();
//	RecordSet.Filter.Document.Set(Document);
//	RecordSet.Filter.Period.Set(ServerDate);
//	
//	RecordSet.Read();
//	
//	Record = RecordSet.Add();
//	Record.Author = CurrentUser;
//	Record.Period = ServerDate;
//	Record.Document = Document;
//	Record.PaymentReminder = PaymentReminder;
//	
//	RecordSet.Write();
//	
//EndProcedure	


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// WEB SERVICE

//Procedure LockObjectForWebService(ObjectRef,User = Undefined) Export
//	
//	If SessionParameters.UseWebServiceLocks Then
//		RecordManager = InformationRegisters.WebServiceLocks.CreateRecordManager();
//		RecordManager.Object = ObjectRef;
//		RecordManager.Read();
//		RecordManager.Object = ObjectRef;
//		If User = Undefined Then
//			User = SessionParameters.CurrentUser;
//		EndIf;	
//		RecordManager.User = User;
//		RecordManager.LockTime = GetServerDate();
//		RecordManager.LastUseTime = RecordManager.LockTime;
//		RecordManager.Write();
//	EndIf;
//	
//EndProcedure	

//Procedure UnLockObjectForWebService(ObjectRef,CheckLock = True) Export
//	
//	If CheckLock Then
//		Query = New Query;
//		Query.Text = "SELECT
//	             |	WebServiceLocks.Object
//	             |FROM
//	             |	InformationRegister.WebServiceLocks AS WebServiceLocks
//	             |WHERE
//	             |	WebServiceLocks.Object = &Object";
//		Query.SetParameter("Object",ObjectRef);
//		QueryResult = Query.Execute();
//		NeedUnlock = NOT QueryResult.IsEmpty();
//	Else
//		NeedUnlock = True;
//	EndIf;	
//	If NeedUnlock Then
//		RecordManager = InformationRegisters.WebServiceLocks.CreateRecordManager();
//		RecordManager.Object = ObjectRef;
//		RecordManager.Delete();
//	EndIf;
//	
//EndProcedure	

//Function SetLastUseTimeForLockedObject(Object,User = Undefined) Export
//	
// 	If User=Undefined Then
//		User = SessionParameters.CurrentUser;
//	EndIf;	

//	RecordManager = InformationRegisters.WebServiceLocks.CreateRecordManager();
//	RecordManager.Object = Object;
//	RecordManager.Read();
//	If RecordManager.Selected() Then
//		RecordManager.LastUseTime = GetServerDate();
//		RecordManager.Write();
//		Return True;
//	Else
//		Return False;
//	EndIf;	
//	
//EndFunction

///////////////////////////////////////////////////////
//Procedure ReportsGeneratingSchedules_WriteScheduledJob(Ref) Export
//	
//	// Create scheduled job	
//	FoundJobs = ScheduledJobs.GetScheduledJobs(New Structure("Metadata, Key",Metadata.ScheduledJobs.ReportsGeneratingSchedules,Ref.UUID()));
//	If FoundJobs = Undefined OR FoundJobs.Count()=0 Then 
//		If Ref.Active Then
//			NewScheduledJob = ScheduledJobs.CreateScheduledJob(Metadata.ScheduledJobs.ReportsGeneratingSchedules);
//			ReportsGeneratingSchedules_WriteCurrentScheduledJob(Ref,NewScheduledJob);
//		EndIf;
//	ElsIf FoundJobs.Count()>0 Then
//		
//		If FoundJobs.Count()>1 Then
//			NumOfJobs = FoundJobs.Count()-2;
//			For i = 0 To NumOfJobs Do
//				FoundJobs[0].Delete();
//			EndDo;	
//		EndIf;
//		
//		If Ref.Active Then
//			ReportsGeneratingSchedules_WriteCurrentScheduledJob(Ref,FoundJobs[0]);
//		Else
//			FoundJobs[0].Delete();
//		EndIf;
//		
//	EndIf;	

//EndProcedure	

//Procedure ReportsGeneratingSchedules_WriteCurrentScheduledJob(Ref,ScheduledJob)
//	
//	ScheduledJob.Key = Ref.UUID();
//	ScheduledJob.Description = Ref.Description;
//	ScheduledJob.Use = Ref.Active;
//	ScheduledJob.UserName = TrimAll(Ref.User.Code);
//	ScheduleUnpacked = Ref.Schedule.Get();
//	If ScheduleUnpacked <> Undefined Then
//		ScheduledJob.Schedule = ScheduleUnpacked;
//	EndIf;
//	CurArray = New Array(1);
//	CurArray.Set(0,Ref);
//	ScheduledJob.Parameters = CurArray;
//	ScheduledJob.Write();

//EndProcedure	

Function IsAccessRight(Metadate, RightName = "", User = Undefined) Export
	Return AccessRight(?(RightName = "", "Read", RightName), Metadate, ?(User = Undefined, InfoBaseUsers.CurrentUser(), User));
EndFunction

// Jack 29.05.2017
//Function GetTransitTable(DocumentBase) Export
//	
//	Query = New Query("SELECT
//	                  |	GoodsIssueItemsLines.LineNumber,
//	                  |	GoodsIssueItemsLines.Item,
//	                  |	GoodsIssueItemsLines.UnitOfMeasure,
//	                  |	GoodsInTransitBalance.QuantityBalance AS QuantityBalanceBase,
//	                  |	ItemsUnitsOfMeasureLine.Quantity / ItemsUnitsOfMeasureBase.Quantity AS UnitOfMeasureRatio,
//	                  |	GoodsInTransitBalance.QuantityBalance / (GoodsIssueItemsLines.Quantity * ItemsUnitsOfMeasureLine.Quantity / ItemsUnitsOfMeasureBase.Quantity) AS QuantityRatio,
//	                  |	GoodsIssueItemsLines.Weight,
//	                  |	GoodsIssueItemsLines.Volume
//	                  |FROM
//	                  |	Document.GoodsIssue.ItemsLines AS GoodsIssueItemsLines
//	                  |		INNER JOIN AccumulationRegister.GoodsInTransit.Balance(, IssueDocument = &IssueDocument) AS GoodsInTransitBalance
//	                  |		ON GoodsIssueItemsLines.Item = GoodsInTransitBalance.Item
//	                  |		LEFT JOIN Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasureLine
//	                  |		ON GoodsIssueItemsLines.Item = ItemsUnitsOfMeasureLine.Ref
//	                  |			AND GoodsIssueItemsLines.UnitOfMeasure = ItemsUnitsOfMeasureLine.UnitOfMeasure
//	                  |		LEFT JOIN Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasureBase
//	                  |		ON GoodsIssueItemsLines.Item = ItemsUnitsOfMeasureBase.Ref
//	                  |			AND GoodsIssueItemsLines.Item.BaseUnitOfMeasure = ItemsUnitsOfMeasureBase.UnitOfMeasure
//	                  |WHERE
//	                  |	GoodsIssueItemsLines.Ref = &IssueDocument
//	                  |
//	                  |FOR UPDATE
//	                  |	AccumulationRegister.GoodsInTransit.Balance");
//		
//	Query.SetParameter("IssueDocument", DocumentBase);
//	
//	Return Query.Execute().Unload();
//	
//EndFunction // GetTransitTable()

//	

