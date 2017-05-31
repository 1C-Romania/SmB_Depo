///////////////////////////////////////////////////////////////////////////////
// DOCUMENTS POSTING

Procedure CheckPostingPermission(DocumentObject, Cancel, Title) Export 
	
	If NOT IsInRole(Metadata.Roles.Right_Administration_ToPostDocumentsBeforeStartAccountingDate) Then
		StartAccountingDate = Constants.StartAccountingDate.Get();
		If ValueIsFilled(StartAccountingDate) AND DocumentObject.Date < StartAccountingDate Then
			Alerts.AddAlert(Title + " " + Nstr("en=""Document with date less than 'Start accounting date' could not be posted!"";pl=""Nie można zatwierdzić dokumentu z datą mniejszą od 'Data rozpoczęcia rachunkowości'!"""),,Cancel,DocumentObject);
		EndIf;
	EndIf;
	
	ErrorMessage = Title + " " + NStr("en='You cannot post documents from closed period!';pl='Nie możesz księgować dokumentów z zamkniętego okresu!'");
	CheckDocumentInClosedPeriod(DocumentObject, Cancel,ErrorMessage);
	If Cancel Then
		Return;
	EndIf;	
		
	DisableRealTimePosting = DocumentObject.AdditionalProperties.Property("DisableRealTimePosting");	
	
	If DocumentObject.Metadata().RealTimePosting = Metadata.ObjectProperties.RealTimePosting.Allow
		And DocumentObject.AdditionalProperties.PostingMode = DocumentPostingMode.Regular
		And NOT DocumentObject.AdditionalProperties.Property("ImmediateStockMovements")
		And Not IsInRole(Metadata.Roles.Right_General_NonRealTimePosting) Then
		If DisableRealTimePosting Then
			Alerts.AddAlert(Title + " " + NStr("en = 'Current document could not be reposted, because it has influence on cost of goods!'; pl = 'Ten dokument nie może być zatwierdzony ponownie, ponieważ on wpływa na koszt towarów!'"),, Cancel,DocumentObject);
		Else	
			Alerts.AddAlert(Title + " " + NStr("en='You can post documents only in real time mode!';pl='Możesz księgować dokumenty wyłącznie w trybie operatywnym!'"),, Cancel,DocumentObject);
		EndIf;	
	EndIf;
	
	AllowToEditDocumentsWithChildren = IsInRole(Metadata.Roles.Right_General_ToModifyDocumentsWithChildren);
	
	If Not AllowToEditDocumentsWithChildren And DocumentsPostingAndNumberingAtServer.HasChildDocuments(DocumentObject) Then
		Alerts.AddAlert(Title + " " + NStr("en='This document has child document(s), so is available for reading only!';pl='Ten dokument ma dokumenty pochodne, zatem jest dostępny tylko do odczytu!'"),, Cancel, DocumentObject);
	EndIf;
	
	If IsInvoiceDocument(DocumentObject.Ref) 
		AND NOT IsInRole(Metadata.Roles.Right_Sales_ToChangeInvoicesAfterPosting)
		AND NOT DocumentObject.AdditionalProperties.WasNew 
		AND DocumentObject.AdditionalProperties.WasPosted Then
		Alerts.AddAlert(Title + " " + NStr("en='You don''t have enough permissions to repost this document!';pl='Nie masz wystarczających uprawnień dla ponownego zatwierdzenia tego dokumentu!'"),, Cancel,DocumentObject);
	EndIf;	
	
EndProcedure // CheckPostingPermission()

Procedure CheckUndoPostingPermission(DocumentObject, Cancel, Title) Export 
	
	If NOT IsInRole(Metadata.Roles.Right_Administration_ToPostDocumentsBeforeStartAccountingDate) Then
		StartAccountingDate = Constants.StartAccountingDate.Get();
		If ValueIsFilled(StartAccountingDate) AND DocumentObject.Date < StartAccountingDate Then
			Alerts.AddAlert(Title + " " + Nstr("en=""Document with date less than 'Start accounting date' could not be unposted!"";pl=""Nie można anulować zatwierdzenia dokumentu z datą mniejszą od 'Data rozpoczęcia rachunkowości'!"""),,Cancel,DocumentObject);
		EndIf;
	EndIf;
	
	ErrorMessage = Title + " " + NStr("en='You cannot undo posting documents from closed period!';pl='Nie możesz odksięgować dokumentów z zamkniętego okresu!'");
	CheckDocumentInClosedPeriod(DocumentObject, Cancel,ErrorMessage);
	
	If Cancel Then
		Return;
	EndIf;	
	
	DisableRealTimePosting = DocumentObject.AdditionalProperties.Property("DisableRealTimePosting");	
		
	If DocumentObject.Metadata().RealTimePosting = Metadata.ObjectProperties.RealTimePosting.Allow
		And Not IsInRole(Metadata.Roles.Right_General_NonRealTimePosting) Then
		If BegOfDay(DocumentObject.Date) < BegOfDay(CurrentDate()) Then
			Alerts.AddAlert(Title + " " + NStr("en='You can undo posting documents only in current date!';pl='Możesz odksięgowywać dokumenty wyłącznie z dzisiejszej datą!'"),, Cancel, DocumentObject);
		ElsIf DisableRealTimePosting Then
			Alerts.AddAlert(Title + " " + NStr("en = 'This document could not be unposted because it has influence on cost of goods!'; pl = 'Nie można anulować zatwierdzenie dokumentu ponieważ ten dokument wpływa na koszt towarów!'"),, Cancel, DocumentObject);
		EndIf;	
	Else
		If DisableRealTimePosting Then
			Alerts.AddAlert(Title + " " + NStr("en = 'Unposting of this document has influence on cost of goods!'; pl = 'Anulowanie zatwierdzenia tego dokumentu może wpłynąć na koszt towarów!'"),Enums.AlertType.Warning,, DocumentObject);
		EndIf;	
	EndIf;
	
	AllowToEditDocumentsWithChildren = IsInRole(Metadata.Roles.Right_General_ToModifyDocumentsWithChildren);
	
	If Not AllowToEditDocumentsWithChildren And DocumentsPostingAndNumberingAtServer.HasChildDocuments(DocumentObject) Then
		Alerts.AddAlert(Title + " " + NStr("en='This document has child document(s), so is available for reading only!';pl='Ten dokument ma dokumenty pochodne, zatem jest dostępny tylko do odczytu!'"),, Cancel,DocumentObject);
	EndIf;
	
	If IsInvoiceDocument(DocumentObject.Ref) AND NOT IsInRole(Metadata.Roles.Right_Sales_ToChangeInvoicesAfterPosting) Then
		Alerts.AddAlert(Title + " " + NStr("en='You don''t have enough permissions to unpost this document!';pl='Nie masz wystarczających uprawnień dla anulowania zatwierdzenia tego dokumentu!'"),, Cancel,DocumentObject);
	EndIf;	
	
EndProcedure // CheckUndoPostingPermission()

Procedure CheckDocumentInClosedPeriod(DocumentObject,Cancel,ErrorMessage)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	ClosedPeriodsSliceLast.Period,
	             |	ClosedPeriodsSliceLast.Company
	             |FROM
	             |	InformationRegister.ClosedPeriods.SliceLast AS ClosedPeriodsSliceLast
	             |WHERE
	             |	ClosedPeriodsSliceLast.Company = &Company";
	
	Query.SetParameter("Company", ?(CommonAtServer.IsDocumentAttribute("Company", DocumentObject.Metadata()), DocumentObject.AdditionalProperties.RefCompany, Catalogs.Companies.EmptyRef()));
	Selection = Query.Execute().Select();
	
	GenerateAlert = False;
	If Selection.Next() Then
		
		If BegOfDay(DocumentObject.Date) <= EndOfDay(Selection.Period) Then
			// Check exeptions
			ExceptionQuery = New Query;
			ExceptionQuery.Text = "SELECT TOP 1
			|	1 AS MarkerField
			|FROM
			|	InformationRegister.ClosedPeriodsExceptions AS ClosedPeriodsExceptions
			|WHERE
			|	ClosedPeriodsExceptions.Company = &Company
			|	AND ClosedPeriodsExceptions.User IN (&User, VALUE(Catalog.Users.EmptyRef))
			|	AND ClosedPeriodsExceptions.DocumentType = &DocumentType
			|	AND CASE
			|			WHEN ClosedPeriodsExceptions.DateFrom <> &EmptyDate
			|				THEN ClosedPeriodsExceptions.DateFrom <= &DocumentDate
			|			ELSE TRUE
			|		END
			|	AND CASE
			|			WHEN ClosedPeriodsExceptions.DateTo <> &EmptyDate
			|				THEN ClosedPeriodsExceptions.DateTo >= &DocumentDate
			|			ELSE TRUE
			|		END";
			ExceptionQuery.SetParameter("Company", ?(CommonAtServer.IsDocumentAttribute("Company", DocumentObject.Metadata()), DocumentObject.AdditionalProperties.RefCompany, Catalogs.Companies.EmptyRef()));
			ExceptionQuery.SetParameter("User",SessionParameters.CurrentUser);
			ExceptionQuery.SetParameter("DocumentType",Documents[DocumentObject.Metadata().Name].EmptyRef());
			ExceptionQuery.SetParameter("DocumentDate",BegOfDay(DocumentObject.Date));
			ExceptionQuery.SetParameter("EmptyDate",'00010101000000');
			QueryResult = ExceptionQuery.Execute();
			If QueryResult.IsEmpty() Then
				GenerateAlert = True;
			EndIf;	
			
		EndIf;
		
		If GenerateAlert Then
			Alerts.AddAlert(ErrorMessage,, Cancel, DocumentObject);
		EndIf;	
	EndIf;
	
EndProcedure	

Function GetVATCalculationMethod(Date,Company) Export
	
	VATCalculationMethod = InformationRegisters.AccountingPolicyGeneral.GetLast(Date, New Structure("Company", Company)).VATCalculationMethod;
	If VATCalculationMethod = Undefined Then
		VATCalculationMethod = Enums.VATCalculationMethod.EmptyRef();
	EndIf;
	
	Return VATCalculationMethod;
	
EndFunction


#If Client Then

Procedure CheckEditingPermission(DocumentForm) Export
	
	DocumentObject = DocumentForm.ThisObject;
	
	If NOT DocumentObject.IsNew() Then
		LockUser = Undefined;
		If WebServicesModule.IsObjectLockedForWebService(DocumentObject.Ref) Then
			ShowMessageBox(, Alerts.ParametrizeString(Nstr("en = 'This document could not be changed because it has been locked by user %P1!';
						|pl = 'Nie można zmienić tego dokumentu ponieważ ten dokument został zablokowany przez użytkownika %P1!'"), New Structure("P1",LockUser)));
			DocumentForm.ReadOnly = True;
			
			If IsInRole(Metadata.Roles.Right_WebService_AllowToUnlockObjects) Then
				
				DocumentForm.Controls.FormActions.Buttons.Add("UnlockObject",CommandBarButtonType.Action,Nstr("pl='Odblokuj'"),New Action("UnlockObject"));
				
			EndIf;	
			
		EndIf;	
	EndIf;	
	
	If Not IsInRole(Metadata.Roles.Right_General_ModifyDocumentsNumber) Then
		DocumentForm.Controls.Number.ReadOnly = True;
	ElsIf DocumentForm.Controls.Number.Data = "" Then
		DocumentForm.Controls.Number.TextEdit = False;
		DocumentForm.Controls.Number.ChoiceButton = True;
		DocumentForm.Controls.Number.ChoiceButtonPicture = PictureLib.Pencil;
	EndIf;
		
	If DocumentForm.Posted Then
		
		If IsInvoiceDocument(DocumentForm.Ref) AND NOT IsInRole(Metadata.Roles.Right_Sales_ToChangeInvoicesAfterPosting) Then
			DocumentForm.ReadOnly = True;
		Else
			
			If DocumentForm.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow
			And DocumentForm.Metadata().RealTimePosting = Metadata.ObjectProperties.RealTimePosting.Allow 
			AND Not IsInRole(Metadata.Roles.Right_General_NonRealTimePosting) Then
				LockDocumentFormByDate(DocumentForm);
			EndIf;
			
			AllowToEditDocumentsWithChildren = IsInRole(Metadata.Roles.Right_General_ToModifyDocumentsWithChildren);
			
			If Not DocumentObject.IsNew() And Not AllowToEditDocumentsWithChildren And DocumentsPostingAndNumberingAtServer.HasChildDocuments(DocumentObject) Then
				
				DocumentForm.ReadOnly = True;
				
			EndIf;	
			
		EndIf;	
	
	EndIf;
			
EndProcedure

Procedure LockDocumentFormByDate(DocumentForm)
	
	If BegOfDay(DocumentForm.Date) < BegOfDay(CurrentDate()) Then
		DocumentForm.ReadOnly = True;
	Else
		DocumentForm.UsePostingMode = PostingModeUse.RealTime;
	EndIf;	
	
EndProcedure	

Procedure CheckEditingPermissionForArchive(DocumentForm) Export
	
	DocumentObject = DocumentForm.ThisObject;
		
	If CommonAtServer.IsDocumentAttribute("IsArchive", DocumentObject.Metadata()) 
		AND DocumentObject.IsArchive Then
		DocumentForm.Controls.Number.ReadOnly = False;
		DocumentForm.Controls.Number.TextEdit = True;
		DocumentForm.Controls.Number.ChoiceButton = False;
		DocumentForm.Controls.Number.Data = "Number";
		DocumentForm.ReadOnly = False;
	EndIf;
		
EndProcedure

#EndIf

Procedure NumberEnabledOnArchiveStatusChange(DocumentForm,ArchiveStatus) Export
	
	If Not ArchiveStatus Then
		DocumentForm.Controls.Number.Data = "Number";
		
		If DocumentForm.ThisObject.IsNew() Then
			DocumentForm.Controls.Number.Value = "";
		EndIf;	
			
		DocumentForm.Controls.Number.ReadOnly = False;
		DocumentForm.Controls.Number.TextEdit = True;
	Else
		If Not IsInRole(Metadata.Roles.Right_General_ModifyDocumentsNumber) Then
			DocumentForm.Controls.Number.ReadOnly = True;
		ElsIf DocumentForm.Controls.Number.Data = "" Then
			DocumentForm.Controls.Number.TextEdit = False;
			DocumentForm.Controls.Number.ChoiceButton = True;
			DocumentForm.Controls.Number.ChoiceButtonPicture = PictureLib.Pencil;
		EndIf;
		If DocumentForm.ThisObject.IsNew() Then
			DocumentForm.Controls.Number.Data = "";
			DocumentForm.Controls.Number.Value = GetDocumentAutoNumberPresentation(DocumentForm.ThisObject);
		EndIf;	
	EndIf;	
	
	
EndProcedure

Procedure CheckSalesAmountAndVATEditingPermission(DocumentForm, TabularPartName = "ItemsLines", AmountColumnsStructure = Undefined) Export
	
	If AmountColumnsStructure = Undefined Then
		AmountColumnsStructure = New Structure("Amount, VATRate, VAT");
	EndIf;
	
	DocumentMetadata = DocumentForm.ThisObject.Metadata();
	
	If Not IsInRole(Metadata.Roles.Right_Sales_ToEditSalesAmountAndVAT) Then
		For each KeyAndValue In AmountColumnsStructure Do
			DocumentForm.Controls[TabularPartName].Columns[KeyAndValue.Key].ReadOnly = True;
		EndDo;
	EndIf;
	
EndProcedure

Function IsInvoiceDocument(DocumentRef)
	
	If TypeOf(DocumentRef) = TypeOf(Documents.SalesInvoice.EmptyRef())
		OR TypeOf(DocumentRef) = TypeOf(Documents.SalesRetail.EmptyRef())
		OR TypeOf(DocumentRef) = TypeOf(Documents.SalesCreditNotePriceCorrection.EmptyRef())
		OR TypeOf(DocumentRef) = TypeOf(Documents.SalesCreditNoteReturn.EmptyRef())
		OR TypeOf(DocumentRef) = TypeOf(Documents.SalesRetailReturn.EmptyRef()) Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// DOCUMENTS NUMBERING
Function GetFieldArray(Val AttributeDescription)
	Result = New Array;
	While Find(AttributeDescription, ".") > 0 Do
		Value = Left(AttributeDescription, Find(AttributeDescription,".") - 1);
		AttributeDescription = Right(AttributeDescription, StrLen(AttributeDescription) - Find(AttributeDescription, "."));
		Result.Add(Value);
	EndDo;
	
	Result.Add(AttributeDescription);
	
	Return Result;
EndFunction

Function GetValueFromObject(DocumentObject, Attribute)
	ArrayAttribute = GetFieldArray(Attribute);
	Value = DocumentObject;
	
	For Each Attribut In ArrayAttribute Do
		Value = Value[Attribut];
	EndDo;
	Return Value;
EndFunction

Function GetDocumentNumberPrefix(Val DocumentObject, InitialCounter = "") Export
	
	DocumentObjectMetadata = DocumentObject.Ref.Metadata();
	
	If CommonAtServer.IsDocumentAttribute("Company", DocumentObjectMetadata) Then
		Company = DocumentObject.Company;
	Else
		Company = Catalogs.Companies.EmptyRef();
	EndIf;
	
	CompanyPrefix = TrimAll(Company.Prefix);
	IsDocumentPrefix = False;
	If CommonAtServer.IsDocumentAttribute("Prefix", DocumentObjectMetadata) And ValueIsFilled(DocumentObject.Prefix) Then
		IsDocumentPrefix = True;
		DocumentPrefixRecord = New Structure("Prefix", DocumentObject.Prefix);
		Query = New Query;
		Query.Text = "SELECT
		|	MAX(DocumentsNumberingSettingsSliceLast.Period) AS Period,
		|	DocumentsNumberingSettingsSliceLast.DocumentType,
		|	DocumentsNumberingSettingsSliceLast.Prefix
		|INTO MaxPeriod
		|FROM
		|	InformationRegister.DocumentsNumberingSettings.SliceLast(
		|			&Period,
		|			DocumentType = &DocumentType
		|				AND Prefix = &Prefix) AS DocumentsNumberingSettingsSliceLast
		|
		|GROUP BY
		|	DocumentsNumberingSettingsSliceLast.DocumentType,
		|	DocumentsNumberingSettingsSliceLast.Prefix
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentsNumberingSettings.DocumentType,
		|	DocumentsNumberingSettings.AttributeValue,
		|	DocumentsNumberingSettings.Prefix,
		|	DocumentsNumberingSettings.InitialCounter,
		|	DocumentsNumberingSettings.Attribute
		|FROM
		|	MaxPeriod AS MaxPeriod
		|		INNER JOIN InformationRegister.DocumentsNumberingSettings AS DocumentsNumberingSettings
		|		ON MaxPeriod.Period = DocumentsNumberingSettings.Period
		|			AND MaxPeriod.DocumentType = DocumentsNumberingSettings.DocumentType
		|			AND MaxPeriod.Prefix = DocumentsNumberingSettings.Prefix";

		Query.SetParameter("Prefix", DocumentObject.Prefix);
	Else
		Query = New Query;
		Query.Text = "SELECT
		|	MAX(DocumentsNumberingSettingsSliceLast.Period) AS Period,
		|	DocumentsNumberingSettingsSliceLast.DocumentType
		|INTO MaxPeriod
		|FROM
		|	InformationRegister.DocumentsNumberingSettings.SliceLast(&Period, DocumentType = &DocumentType) AS DocumentsNumberingSettingsSliceLast
		|
		|GROUP BY
		|	DocumentsNumberingSettingsSliceLast.DocumentType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentsNumberingSettings.DocumentType,
		|	DocumentsNumberingSettings.AttributeValue,
		|	DocumentsNumberingSettings.Prefix,
		|	DocumentsNumberingSettings.InitialCounter,
		|	DocumentsNumberingSettings.Attribute
		|FROM
		|	MaxPeriod AS MaxPeriod
		|		INNER JOIN InformationRegister.DocumentsNumberingSettings AS DocumentsNumberingSettings
		|		ON MaxPeriod.Period = DocumentsNumberingSettings.Period
		|			AND MaxPeriod.DocumentType = DocumentsNumberingSettings.DocumentType";
		
	EndIf;
	
	Query.SetParameter("Period", DocumentObject.Date);
	Query.SetParameter("DocumentType", Documents[DocumentObjectMetadata.Name].EmptyRef());
	
	ResultNumbersSettings = Query.Execute().Unload();
		
	
	If Documents.AllRefsType().ContainsType(TypeOf(DocumentObject.Ref)) Then
		DocumentPrefixRecord = New Structure("Prefix, InitialCounter");
		If ResultNumbersSettings.Count() > 1 Then
			For Each RowNumberSetting In ResultNumbersSettings Do
				If Not ValueIsFilled(RowNumberSetting.AttributeValue) Then
					FillPropertyValues(DocumentPrefixRecord, RowNumberSetting);
				ElsIf GetValueFromObject(DocumentObject, RowNumberSetting.Attribute) = RowNumberSetting.AttributeValue Then
					FillPropertyValues(DocumentPrefixRecord, RowNumberSetting);
				EndIf;
			EndDo;
		Else
			If IsDocumentPrefix And ResultNumbersSettings.Count() = 1 Then
				FillPropertyValues(DocumentPrefixRecord, ResultNumbersSettings[0]);
			Else
				DocumentPrefixRecord = InformationRegisters.DocumentsNumberingSettings.GetLast(DocumentObject.Date, New Structure("DocumentType", Documents[DocumentObjectMetadata.Name].EmptyRef()));
			EndIf;
		EndIf;
	ElsIf BusinessProcesses.AllRefsType().ContainsType(TypeOf(DocumentObject.Ref)) Then
		DocumentPrefixRecord = InformationRegisters.DocumentsNumberingSettings.GetLast(DocumentObject.Date, New Structure("DocumentType", BusinessProcesses[DocumentObjectMetadata.Name].EmptyRef()));	
	ElsIf Tasks.AllRefsType().ContainsType(TypeOf(DocumentObject.Ref)) Then
		DocumentPrefixRecord = InformationRegisters.DocumentsNumberingSettings.GetLast(DocumentObject.Date, New Structure("DocumentType", Tasks[DocumentObjectMetadata.Name].EmptyRef()));		
	EndIf;	
	
	DocumentPrefix = TrimAll(DocumentPrefixRecord.Prefix);
	If IsBlankString(DocumentPrefixRecord.InitialCounter) Then
		InitialCounter = "00001";
	Else
		InitialCounter = TrimAll(DocumentPrefixRecord.InitialCounter);
	EndIf;
	
	If Not TypeOf(DocumentObject) = Type("FormDataStructure") Then
		If Number(InitialCounter) = 1 AND TypeOf(DocumentObject) <> Type("Structure") AND Find(XMLTypeOf(DocumentObject).TypeName, "Ref.") = 0 Then
			DocumentObject.AdditionalProperties.Insert("FirstNumber",True);
		EndIf;	
	EndIf;	
	
	// Parse prefix.
	DocumentPrefix = DocumentsPostingAndNumberingAtClientAtServer.ReplacePrefixTokens_Date(DocumentPrefix, DocumentObject.Date);
	
	// Document's copy prefix for documents that have prefix depends on attributes
	DocumentCopyPrefix = "";
	If SessionParameters.IsBookkeepingAvailable Then
		If TypeOf(DocumentObject) = Type("DocumentObject.BookkeepingOperation") 
			OR TypeOf(DocumentObject.Ref) = Type("DocumentRef.BookkeepingOperation") Then
			DocumentCopyPrefix = TrimAll(DocumentObject.PartialJournal.Prefix);
		EndIf;
	EndIf;
	
	Return CompanyPrefix + DocumentPrefix + DocumentCopyPrefix;
	
EndFunction

#If ThickClientOrdinaryApplication Then
	
Function GetDocumentAutoNumberPresentation(DocumentObject) Export
	
	InitialCounter = "";
	
	Prefix = GetDocumentNumberPrefix(DocumentObject, InitialCounter);
	
	StarStr = "";
	For x = 1 To StrLen(InitialCounter) Do
		StarStr = StarStr + "*";
	EndDo;
	
	Return Prefix + StarStr;
	
EndFunction

Procedure SetNewDocumentPrefix(Source,Cancel) Export
	
	If IsBlankString(Source.Number) Then
		
		If CommonAtServer.IsDocumentAttribute("Company", Source.Metadata()) And Source.Company.IsEmpty() Then
			Alerts.AddAlert(NStr("en='You should define attribute Company!'; pl='Wybierz wartość atrybutu Firma!'"),, Cancel,Source);
			Return;
		EndIf;
		
		InitialCounter = "";
		Prefix = GetDocumentNumberPrefix(Source, InitialCounter);
		NumberLength = Source.Metadata().NumberLength;
		
		Source.SetNewNumber(Prefix);
		
		ZeroStr = "";
		For x = 1 To NumberLength Do
			ZeroStr = ZeroStr + "0";
		EndDo;
		
		SystemFirstNumberWithPrefix = Left(Prefix + ZeroStr, NumberLength - 1) + "1";
		
		If Source.Number = SystemFirstNumberWithPrefix Then
			
			If Source.Number <> Prefix + InitialCounter Then
				Source.Number = Prefix + InitialCounter;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure	

#Else	
&AtServer
Procedure SetNewDocumentPrefix(Source,Cancel) Export
	
	If IsBlankString(Source.Number) Then
		
		If CommonAtServer.IsDocumentAttribute("Company", Source.Metadata()) And Source.Company.IsEmpty() Then
			Alerts.AddAlert(NStr("en='You should define attribute Company!'; pl='Wybierz wartość atrybutu Firma!'"),, Cancel,Source);
			Return;
		EndIf;
		
		InitialCounter = "";
		Prefix = GetDocumentNumberPrefix(Source, InitialCounter);
		NumberLength = Source.Metadata().NumberLength;
		
		Source.SetNewNumber(Prefix);
		
		ZeroStr = "";
		For x = 1 To NumberLength Do
			ZeroStr = ZeroStr + "0";
		EndDo;
		
		SystemFirstNumberWithPrefix = Left(Prefix + ZeroStr, NumberLength - 1) + "1";
		
		If Source.Number = SystemFirstNumberWithPrefix Then
			
			If Source.Number <> Prefix + InitialCounter Then
				Source.Number = Prefix + InitialCounter;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure	

&AtServer
Function GetDocumentAutoNumberPresentation(Val DocumentObject) Export
	
	InitialCounter = "";
	
	Prefix = GetDocumentNumberPrefix(DocumentObject, InitialCounter);
	
	StarStr = "";
	For x = 1 To StrLen(InitialCounter) Do
		StarStr = StarStr + "*";
	EndDo;
	
	Return Prefix + StarStr;
	
EndFunction
#EndIf

Function GetCatalogFirstCode(CatalogObject) Export
	
	CodeLength = CatalogObject.Metadata().CodeLength;
		
	ZeroStr = "";
	For x = 1 To CodeLength Do
		ZeroStr = ZeroStr + "0";
	EndDo;
	
	Return (Left(ZeroStr, CodeLength - 1) + "1");

EndFunction	

Procedure SetCatalogShortFirstCode(CatalogObject,Length = 7) Export
	
	If CatalogObject.Code = GetCatalogFirstCode(CatalogObject) Then
		
		ShortCode = "";
		For x = 1 To Length-1 Do
			ShortCode = ShortCode + "0";
		EndDo;
		
		CatalogObject.Code = ShortCode + "1";
		
	EndIf;	
	
EndProcedure	

Procedure OnStartChangeDocumentAutoNumber(DocumentForm) Export
	
#If Client Then
	If DocumentForm.Controls.Number.Data <> "" Then
		Return;
	EndIf;
	
	Answer = DoQueryBox(NStr("en='ATTENTION! After changing the number automatic numbering for this document will be disabled!"
"Enable number editing?';pl='UWAGA! Po zmianie numeru numeracja automatyczna tego dokumentu zostanie wyłączona!"
"Włączyć moźliwość zmiany numeru?';ru='ВНИМАНИЕ! После изменения номера автоматическая нумерация документов будет отключена!"
"Разрешить редактирование номера документа?'"), QuestionDialogMode.YesNo);
	
	If Answer = DialogReturnCode.Yes Then
		DocumentForm.Number = GetDocumentNumberPrefix(DocumentForm.ThisObject);
		DocumentForm.Controls.Number.Data = "Number";
	EndIf;
#EndIf
	
EndProcedure

Procedure DeleteFromCheckedAttributes(CheckedAttributes, Val DeletingValue) Export
	
	While True Do
		
		FoundItem = CheckedAttributes.Find(DeletingValue);
		If FoundItem = Undefined Then
			Break;
		EndIf;
		
		CheckedAttributes.Delete(FoundItem);
		
	EndDo;	
	
EndProcedure	


// DateOfFiscalization, FiscalizedBy - output parametrs. If document was fiscalized this parameters
// contains return value
Function IsDocumentFiscalised(Document,DateOfFiscalization = Undefined,FiscalizedBy = Undefined) Export
	
	Query = New Query();
	Query.Text = "SELECT
	             |	FiscaledDocuments.Document,
	             |	FiscaledDocuments.Author,
	             |	FiscaledDocuments.DateOfFiscalization
	             |FROM
	             |	InformationRegister.FiscaledDocuments AS FiscaledDocuments
	             |WHERE
	             |	FiscaledDocuments.Document = &Document";
	Query.SetParameter("Document",Document);
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		DateOfFiscalization = Selection.DateOfFiscalization;
		FiscalizedBy = Selection.Author;
	EndIf;	
	
	Return NOT QueryResult.IsEmpty();
	
EndFunction	

// CATALOGS WRITING
Function GetAttributesStructure(AttributesString, Object) Export
	
	AttributesStructure = New Structure(AttributesString);
	For Each KeyAndValue In AttributesStructure Do
		AttributesStructure[KeyAndValue.Key] = Object[KeyAndValue.Key];
	EndDo;
	
	Return AttributesStructure;
	
EndFunction

Procedure ClearDocumentsRecordSets(DocumentObject, ExcludeStructure = Undefined) Export
	
	For Each RegisterRecordSet In DocumentObject.RegisterRecords Do
		
		If (ExcludeStructure = Undefined OR NOT ExcludeStructure.Property(RegisterRecordSet.Metadata().Name)) AND RegisterRecordSet.Count() > 0 Then
			RegisterRecordSet.Clear();
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReadDocumentsRecordSets(DocumentObject, ToReadStructure) Export
	
	For Each KeyAndValue In ToReadStructure Do
		
		DocumentObject.RegisterRecords[KeyAndValue.Key].Read();
		
	EndDo;
	
EndProcedure

Procedure WriteDocumentsRecordSets(DocumentObject, ToWriteStructure) Export
	
	For Each KeyAndValue In ToWriteStructure Do
		
		DocumentObject.RegisterRecords[KeyAndValue.Key].Write();
		
	EndDo;
	
EndProcedure
