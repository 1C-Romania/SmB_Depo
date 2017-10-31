
Procedure DocumentsBookkeepingPosting(Source, Cancel, PostingMode) Export
	
	If Not GetFunctionalOption("UseFinance") Then
		Return;
	EndIf;
	
	If TypeOf(Source.Ref) = Type("DocumentRef.BookkeepingOperation")
		OR TypeOf(Source.Ref) = Type("DocumentRef.ClosePeriod")
		OR TypeOf(Source.Ref) = Type("DocumentRef.CurrencyAccountsValuation") Then
		Return;
	EndIf;
	
	// Documents without company couldn't be posted in bookkeeping.
	If Not CommonAtServer.IsDocumentAttribute("Company", Source.Ref.Metadata()) Then
		Return;
	EndIf;
	
	If Hour(Source.Date)=23 and Minute(Source.Date)=59 and Second(Source.Date)>49 Then
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'An error occurred during posting Bookkeeping operation for document %P1. Document should have one record in register ''BookkeepingPostedDocuments'''; pl = 'Nieprawidłowa godzina. Dla dokumentu %P1 godzina powinna mieścić się w przedziale 00:00:00 do 23:59:49.'"),New Structure("P1",Source.Ref)),Enums.AlertType.Error,Cancel,Source);	
		Return;
	EndIf;
	
	MetadataName = Source.Ref.Metadata().Name;
	If Left(MetadataName,1) = "_" Then
		// removed document
		BookkeepingPostingType = Enums.BookkeepingPostingTypes.DontPost
	Else	
		BookkeepingPostingType = InformationRegisters.BookkeepingPostingSettings.Get(New Structure("Object", Documents[MetadataName].EmptyRef())).BookkeepingPostingType;
		If Not ValueIsFilled(BookkeepingPostingType) Then
			BookkeepingPostingType = Enums.BookkeepingPostingTypes.Delayed;
		EndIf;
	EndIf;
	
	If BookkeepingPostingType = Enums.BookkeepingPostingTypes.DontPost Then
		// This document type is not bookkeeping posted
		Return;
	EndIf;
	
	For Each RegisterRecordSet In Source.RegisterRecords Do
		If RegisterRecordSet.Modified() Then
			RegisterRecordSet.Write();
		EndIf;
	EndDo;
	
	// Jack 29.05.2017
	//If Source.AdditionalProperties.Property("CostOfGoodsSequenceRestoring") Then
	//	AreDifferences = False;
	//	If Source.AdditionalProperties.Property("IsCostOfGoodsRecorder") Then
	//		CostOfGoodsAfterWriteValueTable = Comparison.GetValueTableFromRecordSet("CostOfGoods",Source.Ref);
	//		CostOfGoodsBeforeWriteValueTable = Undefined;
	//		Source.AdditionalProperties.Property("CostOfGoodsBeforeWriteValueTable",CostOfGoodsBeforeWriteValueTable);
	//		ComparisonResult = Comparison.CompareValueTables(CostOfGoodsBeforeWriteValueTable,CostOfGoodsAfterWriteValueTable);
	//		AreDifferences = AreDifferences OR ComparisonResult.AreDifferences;
	//	EndIf;	
	//	
	//	If NOT AreDifferences AND Source.AdditionalProperties.Property("IsCostOfGoodsTurnoversRecorder") Then
	//		CostOfGoodsTurnoversAfterWriteValueTable = Comparison.GetValueTableFromRecordSet("CostOfGoodsTurnovers",Source.Ref);
	//		CostOfGoodsTurnoversBeforeWriteValueTable = Undefined;
	//		Source.AdditionalProperties.Property("CostOfGoodsTurnoversBeforeWriteValueTable",CostOfGoodsTurnoversBeforeWriteValueTable);
	//		ComparisonResult = Comparison.CompareValueTables(CostOfGoodsBeforeWriteValueTable,CostOfGoodsAfterWriteValueTable);
	//		AreDifferences = AreDifferences OR ComparisonResult.AreDifferences;
	//	EndIf;	
	//	
	//	If NOT AreDifferences Then
	//		Return;
	//	EndIf;	
	//EndIf;
	
	IsManagedLock = (Source.Metadata().DataLockControlMode = Metadata.ObjectProperties.DefaultDataLockControlMode.Managed);
	If IsManagedLock Then
		DataLock = New DataLock;
		DataLockItem = DataLock.Add("InformationRegister.BookkeepingPostedDocuments");
		DataLockItem.Mode = DataLockMode.Exclusive;
		DataLockItem.SetValue("Document",Source.Ref);
		DataLock.Lock();
	EndIf;
	
	RecordSet = InformationRegisters.BookkeepingPostedDocuments.CreateRecordSet();
	RecordSet.Filter.Document.Set(Source.Ref);
	RecordSet.Read();
	
	Count = RecordSet.Count();
	DocumentBecamePosted = False;
	If RecordSet.Count() = 0 Then
		Record = RecordSet.Add();
		DocumentBecamePosted = True;
	Else
		Record = RecordSet[0];
	EndIf;
	
	Record.Company = Source.Company;
	Record.Date = Source.Date;
	Record.DocumentType = Documents[Source.Metadata().Name].EmptyRef();
	Record.Document = Source.Ref;
	Record.Status = Enums.DocumentBookkeepingStatus.NotBookkeepingPosted;
	
	If DocumentBecamePosted Then
		RecordSet.SetProgramBookkeepingPostingFlag();
		RecordSet.Write();
	EndIf;	
	
	ReturnStructure = Privileged.DocumentBookkeepingPostingProcessing(BookkeepingPostingType, Source.Ref, Source.AdditionalProperties.Property("CostOfGoodsSequenceRestoring"), DocumentBecamePosted, Cancel,NOT IsManagedLock);
	
	If ReturnStructure.Status = Enums.DocumentBookkeepingStatus.NotBookkeepingPosted
		AND ValueIsFilled(ReturnStructure.Details) Then
		// CostOfGoodsRestoring
		Source.AdditionalProperties.Insert("UnpostBookkeepingOperation",ReturnStructure.Details);
		Return;
		
	EndIf;	
	
	Record.Status = ReturnStructure.Status;
	
	RecordSet.SetProgramBookkeepingPostingFlag();
	RecordSet.Write();
	
EndProcedure

Procedure DocumentsBookkeepingUndoPosting(Source, Cancel) Export
	
	If Not GetFunctionalOption("UseFinance") Then
		Return;
	EndIf;
	
	If TypeOf(Source.Ref) = Type("DocumentRef.BookkeepingOperation") Then
		Return;
	EndIf;
	
	IsManagedLock = (Source.Metadata().DataLockControlMode = Metadata.ObjectProperties.DefaultDataLockControlMode.Managed);
	Privileged.DocumentBookkeepingUndoPostingProcessing(Source.Ref,NOT IsManagedLock);
	
	If IsManagedLock Then
		DataLock = New DataLock;
		DataLockItem = DataLock.Add("InformationRegister.BookkeepingPostedDocuments");
		DataLockItem.Mode = DataLockMode.Exclusive;
		DataLockItem.SetValue("Document",Source.Ref);
		DataLock.Lock();
	EndIf;
	
	// Clear register information
	RecordSet = InformationRegisters.BookkeepingPostedDocuments.CreateRecordSet();
	RecordSet.Filter.Document.Set(Source.Ref);
	RecordSet.Read();
	RecordSet.Clear();
	RecordSet.SetProgramBookkeepingPostingFlag();
	RecordSet.Write();
	
EndProcedure
