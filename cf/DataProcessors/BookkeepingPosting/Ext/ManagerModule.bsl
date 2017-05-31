Procedure LoadTabularPartFromQueryResult(Val DocumentListVT, Val QueryResultVT, Val StorageAddress) Export
	
	If QueryResultVT.Count()>0 Then
		Percentage100Count = QueryResultVT.Count();
		OneDocumentStep = 100/Percentage100Count;
		IncrementalCounter = 0;
		
		For Each Selection In QueryResultVT Do
			
			IncrementalCounter = IncrementalCounter + OneDocumentStep;
			DataProcessors.BookkeepingPosting.AddTabularPartRow(DocumentListVT,Selection);
			LongActionsServer.WriteProgress(IncrementalCounter);
			
		EndDo;
	EndIf;
	
	PutToTempStorage(DocumentListVT,StorageAddress);
	
EndProcedure	

Procedure AddTabularPartRow(DocumentListVT, Val Selection) Export
	
	NewRow = DocumentListVT.Add();
	
	If Selection.BookkeepingOperationRef = Null Then
		
		BookkeepingOperationTemplate = Undefined;
		Result = BookkeepingCommon.GetRecommendSchemaForDocument(Selection.Document, BookkeepingOperationTemplate, False);
		
		If Result = 0 Then
			NewRow.Remarks = Nstr("en = 'There is no bookkeeping operation template found'; pl = 'Nie znaleziono pasującego schematu księgowania'");
		ElsIf Result = 1 Then
			NewRow.BookkeepingOperationTemplate = BookkeepingOperationTemplate;
		ElsIf Result = 2 Then
			NewRow.Remarks = Nstr("en = 'There are more than one bookkeeping operation template found, corresponding to filter'; pl = 'Istnieje więcej niz jeden pasujacy schemat, który zawiera filtr'");
		ElsIf Result = 3 Then
			NewRow.Remarks = Nstr("en = 'There are more than one bookkeeping operation template found'; pl = 'Istnieje więcej niz jeden pasujacy schemat'");
		EndIf;
		
	Else
		
		NewRow.BookkeepingOperationTemplate = Selection.BookkeepingOperationTemplate;
		
	EndIf;
	
	NewRow.Document = Selection.Document;
	NewRow.DocumentAuthor = Selection.DocumentAuthor;
	NewRow.DocumentComment = Selection.DocumentComment;
	NewRow.Status = Selection.Status;
	NewRow.BookkeepingOperation = Selection.BookkeepingOperationRef;
	NewRow.BookkeepingOperationPosted = Selection.BookkeepingOperationPosted;
	NewRow.BookkeepingOperationDeletionMark = Selection.BookkeepingOperationDeletionMark;
	NewRow.BookkeepingOperationNumber = Selection.BookkeepingOperationNumber;
	NewRow.BookkeepingOperationAuthor = Selection.BookkeepingOperationAuthor;
	NewRow.BookkeepingOperationManual = Selection.BookkeepingOperationManual;
	NewRow.BookkeepingOperationComment = Selection.BookkeepingOperationComment;
	
EndProcedure	

Procedure ProcessTabularPartRows(Val CommandStructure, Val DocumentListVT, Val DynamicFilter, Val DisplayedDocumentsStatus, Val StorageAddress) Export
	
	DocumentListCount = DocumentListVT.Count();
	StepProgress = 100 / DocumentListCount;
	Progress = 0;
	
	i = 1;
	While i<=DocumentListCount Do
		
		DocumentsListRow = DocumentListVT[i-1];
		
		i = i + 1;
		
		Progress = Progress + StepProgress;
		
		LongActionsServer.WriteProgress(Progress);
		
		If Not DocumentsListRow.Check Then
			Continue;
		EndIf;
		
		CheckStatus = DisplayedDocumentsStatus;
		If CommandStructure.Name = "SetStatus" Then
			
			If CommandStructure.NewStatus = Enums.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed 
				And Not DocumentsListRow.BookkeepingOperation.IsEmpty() Then
				DocumentsListRow.Remarks = Nstr("en='Document could not be marked as such that should not be bookkeeping posted, because it already has bookkeeping operation!';pl='Nie można oznaczyć dokument jak taki, któy się nie księguje bo dokument już posiada DK!';ru='Документ, который уже проведен нельзя отметить как документ, который не проводится!'");
				Continue;
			EndIf;
			
			SetDocumentsStatus(DocumentsListRow, CommandStructure.NewStatus, CommandStructure.NewComment);
			
			CheckStatus = CommandStructure.NewStatus;
			
		ElsIf CommandStructure.Name = "UndoPosting" Then
			
			If Not DocumentsListRow.BookkeepingOperationPosted Then
				Continue;
			EndIf;
		
			BOObject = DocumentsListRow.BookkeepingOperation.GetObject();
			BOObject.Write(DocumentWriteMode.UndoPosting);
			
			SetDocumentsStatus(DocumentsListRow, Enums.DocumentBookkeepingStatus.NotBookkeepingPosted, "");
			
			CheckStatus =  Enums.DocumentBookkeepingStatus.NotBookkeepingPosted;
			
		ElsIf CommandStructure.Name = "Posting" Then
			
			If DocumentsListRow.BookkeepingOperationTemplate.IsEmpty() Then
				Continue;
			EndIf;
		
			If DocumentsListRow.BookkeepingOperation.IsEmpty() Then
				DocumentBookkeepingOperation = Documents.BookkeepingOperation.CreateDocument();
				DocumentBookkeepingOperation.Author = SessionParameters.CurrentUser;
			Else
				DocumentBookkeepingOperation = DocumentsListRow.BookkeepingOperation.GetObject();
			EndIf;
			
			If DocumentBookkeepingOperation.Manual = False Then
				DocumentBookkeepingOperation.FillingOnDocumentBaseAndTemplate(DocumentsListRow.Document, DocumentsListRow.BookkeepingOperationTemplate);
				BookkeepingOperationsTemplateObject = DocumentsListRow.BookkeepingOperationTemplate.GetObject();
				BookkeepingOperationsTemplateObject.FillBookkeepingDocument(DocumentsListRow.Document, DocumentBookkeepingOperation);
			Else
				MessageText = Alerts.ParametrizeString(Nstr("en = 'Records generation was not done for document %P1, because it has setted property ""Allow changes""!'; pl = 'Generowanie aktualnych zapisów dla dokumentu %P1 nie została dokonana, ponieważ dokument ma ustawioną cechę ""Pozwól na zmiany""'"), New Structure("P1", DocumentsListRow.Document));
				DocumentsListRow.Remarks = DocumentsListRow.Remarks + MessageText;
				Alerts.AddAlert(MessageText);
			EndIf;	
		
			Try
				
				If CommandStructure.IsDraft Then
					WriteMode = DocumentWriteMode.Write;
					RemarkText = Nstr("en='Document was bookkeeping created successfully';pl='Dowód księgowy został utworzony poprawnie'");
					If DocumentBookkeepingOperation.Posted Then
						Status = Enums.DocumentBookkeepingStatus.BookkeepingPosted;
					Else
						Status = Enums.DocumentBookkeepingStatus.NotBookkeepingPosted;
					EndIf;
				Else
					WriteMode = DocumentWriteMode.Posting;
					RemarkText = Nstr("en = 'Document was bookkeeping posted successfully'; pl = 'Dokument zaksięgowany poprawnie'");
					Status = Enums.DocumentBookkeepingStatus.BookkeepingPosted;
				EndIf;
				
				DocumentBookkeepingOperation.Write(WriteMode);
				DocumentsListRow.BookkeepingOperation = DocumentBookkeepingOperation.Ref;
				DocumentsListRow.BookkeepingOperationPosted = DocumentBookkeepingOperation.Posted;
				DocumentsListRow.BookkeepingOperationNumber = DocumentBookkeepingOperation.Number;
				DocumentsListRow.Remarks = RemarkText;
				DocumentsListRow.Status = Status;
				DocumentsListRow.ActionState = Enums.ActionStates.Performed;
				
			Except
				
				MessageText = Alerts.ParametrizeString(Nstr("en = 'Bookkeeping posting of document %P1 fails!'; pl = 'Księgowanie dokumentu %P1 nie powiodło się!'"), New Structure("P1", DocumentsListRow.Document));
				DocumentsListRow.Remarks = DocumentsListRow.Remarks + MessageText;
				DocumentsListRow.ActionState = Enums.ActionStates.PerformedError;
				Alerts.AddAlert(MessageText);
				
			EndTry;
			
			CheckStatus = Status;
			
		EndIf;
		
		If DynamicFilter AND CheckStatus <> DisplayedDocumentsStatus Then
			
			i = i - 1;
			DocumentListVT.Delete(i-1);
			DocumentListCount = DocumentListCount - 1;
			
		EndIf;
		
	EndDo;	
	
	PutToTempStorage(DocumentListVT,StorageAddress);
	
EndProcedure	

Procedure SetDocumentsStatus(DocumentsListRow,Val NewStatus,Val StatusComment) Export
	
	BeginTransaction(DataLockControlMode.Managed);
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add("InformationRegister.BookkeepingPostedDocuments");
	DataLockItem.Mode = DataLockMode.Exclusive;
	DataLockItem.SetValue("Document",DocumentsListRow.Document);
	DataLock.Lock();
	
	RecordSet = InformationRegisters.BookkeepingPostedDocuments.CreateRecordSet();
	RecordSet.Filter.Document.Set(DocumentsListRow.Document);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		Record = RecordSet.Add();
	Else
		Record = RecordSet[0];
	EndIf;
	
	Record.Status = NewStatus;
	If NewStatus = Enums.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed Then
		Record.Author = SessionParameters.CurrentUser;
		Record.Comment = StatusComment;
	ElsIf DocumentsListRow.BookkeepingOperation.IsEmpty() Then
		Record.Author = Undefined;
		Record.Comment = Undefined;
	EndIf;
	
	RecordSet.SetProgramBookkeepingPostingFlag();
	
	Cancel = False;
	
	Try
		
		RecordSet.Write();
		
		DocumentsListRow.Status = NewStatus;
		
		If NewStatus = Enums.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed Then
			DocumentsListRow.BookkeepingOperationAuthor = SessionParameters.CurrentUser;
			DocumentsListRow.BookkeepingOperationComment = StatusComment;
		ElsIf DocumentsListRow.BookkeepingOperation.IsEmpty() Then
			DocumentsListRow.BookkeepingOperationAuthor = Undefined;
			DocumentsListRow.BookkeepingOperationComment = Undefined;
		EndIf;
		
	Except
		
		MessageText = Alerts.ParametrizeString(Nstr("en = 'Changing status of document %P1 fails!'; pl = 'Zmiana statusu dokumentu %P1 nie powiodła się!'"), New Structure("P1", DocumentsListRow.Document));
		Alerts.AddAlert(MessageText,,Cancel);
		DocumentsListRow.Remarks = ErrorInfo().Description;
		
	EndTry;
	
	If Cancel Then
		RollbackTransaction();
	Else
		CommitTransaction();
	EndIf;	
	
EndProcedure
