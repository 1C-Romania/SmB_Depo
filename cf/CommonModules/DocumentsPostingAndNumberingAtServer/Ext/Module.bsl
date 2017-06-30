// Jack 29.06.2017
//Procedure CheckSalesAmountAndVATEditingPermission(DocumentForm, TabularPartName = "ItemsLines", AmountColumnsStructure = Undefined) Export
//	
//	If AmountColumnsStructure = Undefined Then
//		AmountColumnsStructure = New Structure("Amount, VATRate, VAT");
//	EndIf;
//	
//	IsManagedForm = (TypeOf(DocumentForm) = Type("ManagedForm"));
//	
//	If IsManagedForm Then
//		DocumentMetadata = DocumentForm.Object.Ref.Metadata();
//	Else	
//		DocumentMetadata = DocumentForm.Ref.Metadata();
//	EndIf;
//		
//	If Not IsInRole(Metadata.Roles.Right_Sales_ToEditSalesAmountAndVAT) Then
//		For each KeyAndValue In AmountColumnsStructure Do
//			If IsManagedForm Then
//				DocumentForm.Items[TabularPartName+KeyAndValue.Key].ReadOnly = True;
//			Else	
//				DocumentForm.Controls[TabularPartName].Columns[KeyAndValue.Key].ReadOnly = True;
//			EndIf;	
//		EndDo;
//	EndIf;
//	
//EndProcedure

//Procedure CheckEditingPermissionManaged(DocumentForm) Export
//	
//	DocumentObject = DocumentForm.Object;
//		
//	If Not IsInRole(Metadata.Roles.Right_General_ModifyDocumentsNumber) Then
//		DocumentForm.Items.Number.ReadOnly = True;
//	EndIf;
//		
//	If DocumentObject.Posted Then
//		
//		If ObjectsExtensionsAtClientAtServer.IsInvoiceDocument(DocumentObject.Ref) AND NOT IsInRole(Metadata.Roles.Right_Sales_ToChangeInvoicesAfterPosting) Then
//			DocumentForm.ReadOnly = True;
//		Else
//			DocumentObjectMetadata = DocumentObject.Ref.Metadata();
//			
//			If DocumentObjectMetadata.Posting = Metadata.ObjectProperties.Posting.Allow
//			And DocumentObjectMetadata.RealTimePosting = Metadata.ObjectProperties.RealTimePosting.Allow 
//			AND Not IsInRole(Metadata.Roles.Right_General_NonRealTimePosting) Then
//				LockDocumentFormByDateManaged(DocumentForm);
//			EndIf;
//			
//			AllowToEditDocumentsWithChildren = IsInRole(Metadata.Roles.Right_General_ToModifyDocumentsWithChildren);
//			
//			If Not DocumentForm.Parameters.Key.IsEmpty() And Not AllowToEditDocumentsWithChildren And DocumentsPostingAndNumberingAtServer.HasChildDocuments(DocumentObject.Ref) Then
//				
//				DocumentForm.ReadOnly = True;
//				
//			EndIf;	
//			
//		EndIf;	
//	
//	EndIf;
//			
//EndProcedure

Function HasChildDocuments(Val DocumentObject) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	DocumentHierarchy.Recorder
	             |FROM
	             |	InformationRegister.DocumentHierarchy AS DocumentHierarchy
	             |WHERE
	             |	DocumentHierarchy.ParentDocument = &ParentDocument";
	
	Query.SetParameter("ParentDocument", DocumentObject.Ref);
	
	Selection = Query.Execute().Select();
	
	Return Selection.Next();
	
EndFunction

Procedure CommonDocumentFormManagedOnOpenEnd(ThisForm,ThisObject) Export
	// Jack 29.06.2017
	//CheckEditingPermissionManaged(ThisForm);
	
EndProcedure	

Procedure LockDocumentFormByDateManaged(DocumentForm)
		
	If BegOfDay(DocumentForm.Object.Date) < BegOfDay(CurrentDate()) Then
		DocumentForm.ReadOnly = True;
	Else
		DocumentForm.UsePostingMode = PostingModeUse.RealTime;
	EndIf;	
	
EndProcedure	

Function GetDocumentNumberPrefix(Val DocumentObject, InitialCounter = "") Export
	
	// to do
	// Jack 29.06.2017
	//DocumentObjectMetadata = DocumentObject.Ref.Metadata();
	//If ObjectsExtensionsAtServer.IsDocumentAttribute("Company", DocumentObjectMetadata) Then
	//	Company = DocumentObject.Company;
	//Else
	//	Company = Catalogs.Companies.EmptyRef();
	//EndIf;
	//
	//CompanyPrefix = TrimAll(Company.Prefix);
	//
	//If Documents.AllRefsType().ContainsType(TypeOf(DocumentObject.Ref)) Then
	//	DocumentPrefixRecord = InformationRegisters.DocumentsNumberingSettings.GetLast(DocumentObject.Date, New Structure("DocumentType", Documents[DocumentObjectMetadata.Name].EmptyRef()));
	//ElsIf BusinessProcesses.AllRefsType().ContainsType(TypeOf(DocumentObject.Ref)) Then
	//	DocumentPrefixRecord = InformationRegisters.DocumentsNumberingSettings.GetLast(DocumentObject.Date, New Structure("DocumentType", BusinessProcesses[DocumentObjectMetadata.Name].EmptyRef()));	
	//ElsIf Tasks.AllRefsType().ContainsType(TypeOf(DocumentObject.Ref)) Then
	//	DocumentPrefixRecord = InformationRegisters.DocumentsNumberingSettings.GetLast(DocumentObject.Date, New Structure("DocumentType", Tasks[DocumentObjectMetadata.Name].EmptyRef()));		
	//EndIf;	
	//
	//DocumentPrefix = TrimAll(DocumentPrefixRecord.Prefix);
	//If IsBlankString(DocumentPrefixRecord.InitialCounter) Then
	//	InitialCounter = "00001";
	//Else
	//	InitialCounter = TrimAll(DocumentPrefixRecord.InitialCounter);
	//EndIf;
	//
	//// Parse prefix.
	//DocumentPrefix = DocumentsPostingAndNumberingAtClientAtServer.ReplacePrefixTokens_Date(DocumentPrefix, DocumentObject.Date);
	//
	//// Document's copy prefix for documents that have prefix depends on attributes
	//DocumentCopyPrefix = "";
	//If SessionParameters.IsBookkeepingAvailable Then
	//	If TypeOf(DocumentObject) = Type("DocumentObject.BookkeepingOperation") Then
	//		DocumentCopyPrefix = TrimAll(DocumentObject.PartialJournal.Prefix);
	//	EndIf;
	//EndIf;
	
	//Return CompanyPrefix + DocumentPrefix + DocumentCopyPrefix;
	Return "";
	
EndFunction

Function GetNewDocumentNumber(Form) Export
	
	Number = Form.Object.Number;	
	ObjectRef = Form.Object.Ref;	
	ObjectStructure = ObjectsExtensionsAtServer.FormDataStructureToStructure(Form.Object);		
	ObjectMetadataName = ObjectRef.Metadata().Name;
	
	SetPrivilegedMode(True);
	RefreshObjectsNumbering(ObjectRef.Metadata());	
	SetPrivilegedMode(False);
	
	MetadataObject = ObjectRef.Metadata();
	
	PrefixList = New ValueList;	
	Prefix = "";
	If CommonAtServer.IsDocumentAttribute("Prefix", MetadataObject) Then
		Prefix = Form.Object.Prefix;
		PrefixList.LoadValues(DocumentsPostingAndNumberingAtServer.GetArrayPrefix(MetadataObject, ObjectStructure.Date));		
	EndIf;


	If IsBlankString(Prefix) AND PrefixList.Count()>0 Then
		// there is only one prefix or none - try to obtain it from prefixes array
		CurPrefix = PrefixList[0].Value;
	Else
		CurPrefix = Prefix;
	EndIf;	
	
	If IsBlankString(CurPrefix) Then
		CurPrefix = DocumentsPostingAndNumbering.GetDocumentNumberPrefix(ObjectStructure)
	Else
		CurPrefix = DocumentsPostingAndNumberingAtClientAtServer.ReplacePrefixTokens_Date(CurPrefix,ObjectStructure.Date);
	EndIf;	
	
	// Document's copy prefix for documents that have prefix depends on attributes
	// Only for BookkeepingOperation
	DocumentCopyPrefix = "";
	If SessionParameters.IsBookkeepingAvailable Then
		If TypeOf(ObjectRef) = Type("DocumentRef.BookkeepingOperation") Then
			DocumentCopyPrefix = TrimAll(ObjectStructure.PartialJournal.Prefix);
		EndIf;
	EndIf;
	
	CurPrefix = CurPrefix + DocumentCopyPrefix;
	
	
	Query = New Query;
	
	Query.Text = "SELECT TOP 1
	|	" + ObjectMetadataName + ".Number
	|FROM
	|	Document." + ObjectMetadataName + " AS " + ObjectMetadataName + "
	|WHERE
	|	CASE WHEN &Prefix = """" THEN TRUE ELSE SUBSTRING(" + ObjectMetadataName + ".Number, 1, " + Format(StrLen(CurPrefix), "NG=; NZ=0") + ") = &Prefix END ORDER BY Number DESC";
	
	Query.SetParameter("Prefix", CurPrefix);
	
	Result = Query.Execute();
	Selection = Result.Select();
	LastNumber = "";
	While Selection.Next() Do
		
		LastFullNumber = Selection.Number;
		
	EndDo;
	LastFullNumber = TrimAll(LastFullNumber);
	BaseLastNumber = StrReplace(LastFullNumber, CurPrefix, "");
	
	If LastFullNumber = "" Then
		TempInitialCounter = "";
		Number = DocumentsPostingAndNumbering.GetDocumentNumberPrefix(ObjectStructure,TempInitialCounter); 
		Number = Number + TempInitialCounter;
	Else	
		LastNumber = "";
		For i = 1 To StrLen(BaseLastNumber) Do
			If Mid(BaseLastNumber, i, 1) >= "1" And Mid(BaseLastNumber, i, 1) <= "9" Then
				LastNumber = LastNumber + Mid(BaseLastNumber, i, 1);
			EndIf;
		EndDo;
		Try
			LastNumber = Number(LastNumber);		
		Except
			LastNumber = 0;				
		EndTry;

		NewNumber = Format(LastNumber + 1, "NG=");
		While StrLen(NewNumber) < StrLen(LastFullNumber) - StrLen(CurPrefix) Do
			NewNumber = "0" + NewNumber;
		EndDo;
		NewNumber = CurPrefix + NewNumber;
		Number = NewNumber;		
	EndIf;
	Return Number;
EndFunction

&AtServer
Function GetArrayPrefix(MetadataObject, Date) Export
	
	Query = New Query;
	Query.Text = "SELECT
	|	DocumentsNumberingSettingsSliceLast.Prefix
	|FROM
	|	InformationRegister.DocumentsNumberingSettings.SliceLast(&Date, DocumentType = &DocumentType) AS DocumentsNumberingSettingsSliceLast";
	
	Query.SetParameter("Date", Date);
	Query.SetParameter("DocumentType", Documents[MetadataObject.Name].EmptyRef());
	
	Return Query.Execute().Unload().UnloadColumn("Prefix");
	
EndFunction

&AtServer
Procedure SetBaseNumberPresentationAtServer(Form) Export
	ObjectStructure = ObjectsExtensionsAtServer.FormDataStructureToStructure(Form.Object);	
	If ValueIsNotFilled(Form.Object.Number) AND Form.Object.Ref.IsEmpty() Then		
		Form.NumberPreview = TrimAll(DocumentsPostingAndNumbering.GetDocumentAutoNumberPresentation(ObjectStructure));
		Form.Modified = True;				
	EndIf;			
	DocumentsFormAtServer.SetFormDocumentTitle(Form);		
EndProcedure

&AtServer
Procedure SetNewNumberAtServer(Form) Export	
	Answer = DocumentsPostingAndNumberingAtServer.GetNewDocumentNumber(Form);		
	If TrimAll(Answer) <> TrimAll(Form.Object.Number) Then
		Form.Object.Number = Answer;
		Form.ShowNumberPreview = False;
		DocumentsFormAtServer.SetFormDocumentTitle(Form);				
		Form.Modified = True;											
	EndIf;

EndProcedure

