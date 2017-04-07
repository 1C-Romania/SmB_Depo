&AtServer
Var MTree, MAlreadyInList;

&AtServer
Var MDocumentCacheAttributes;

///////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure outputs the document hierarchy structure tree.
//
Procedure DisplayDocumentTree()
	
	Try
	DocumentsTree.GetItems().Clear();
	MTree = DocumentsTree;	
	MAlreadyInList = New Map;
	MDocumentCacheAttributes = New Map;
	
	OutputParentDocuments(DocumentRef);
	
	OutputSubordinateDocuments(MTree);
	
	Except
		Raise;
	EndTry;
	
EndProcedure

&AtServer
// Procedure executes output of the parent documents.
//
Procedure OutputParentDocuments(DocumentRef)
	
	DocumentMetadata = DocumentRef.Metadata();
	AttributesList = New ValueList;
	
	For Each Attribute IN DocumentMetadata.Attributes Do
		TypesAttribute = Attribute.Type.Types();
		For Each CurrentType IN TypesAttribute Do
			AttributeMetadata = Metadata.FindByType(CurrentType);
			
			If AttributeMetadata<>Undefined AND Metadata.Documents.Contains(AttributeMetadata) 
				 AND AccessRight("Read", AttributeMetadata) Then
				Try
					AttributeValue = DocumentRef[Attribute.Name];
				Except
					Break;
				EndTry;
				If AttributeValue<>Undefined AND Not AttributeValue.IsEmpty() AND TypeOf(AttributeValue) = CurrentType 
					 AND MAlreadyInList[AttributeValue] = Undefined AND AttributesList.FindByValue(DocumentRef[Attribute.Name]) = Undefined Then
					Try
						AttributesList.Add(AttributeValue,Format(AttributeValue.Date,"DF=yyyyMMddHHMMss"));
					Except
						 DebuggingErrorText = ErrorDescription();
					EndTry;
				EndIf;
			EndIf;
			
		EndDo;
	EndDo;
	
	For Each CWT IN DocumentMetadata.TabularSections Do
		
		If DocumentMetadata = Metadata.Documents.SettlementsReconciliation Then
			
			Break;
			
		EndIf;
		
		PageAttributes = "";
		
		Try
			TSContent = DocumentRef[CWT.Name].Unload();
		Except
			Break;
		EndTry;
		
		For Each Attribute IN CWT.Attributes Do
			TypesAttribute = Attribute.Type.Types();
			For Each CurrentType IN TypesAttribute Do
				AttributeMetadata = Metadata.FindByType(CurrentType);
				If AttributeMetadata<>Undefined AND Metadata.Documents.Contains(AttributeMetadata) 
					AND AccessRight("Read", AttributeMetadata) Then
					PageAttributes = PageAttributes + ?(PageAttributes = "", "", ", ") + Attribute.Name;
					Break;
				EndIf;
			EndDo;
		EndDo;
		
		TSContent.GroupBy(PageAttributes);
		For Each ColumnTS IN TSContent.Columns Do
			For Each TSRow IN TSContent Do
				Try
					AttributeValue = TSRow[ColumnTS.Name];
				Except
					Continue;
				EndTry;
				ValueMetadata = Metadata.FindByType(TypeOf(AttributeValue));
				If ValueMetadata = Undefined Then
					// base type
					Continue;
				EndIf;
				
				If AttributeValue<>Undefined AND Not AttributeValue.IsEmpty()
					 AND Metadata.Documents.Contains(ValueMetadata)
					 AND MAlreadyInList[AttributeValue] = Undefined Then
					If AttributesList.FindByValue(AttributeValue) = Undefined Then
						Try
							AttributesList.Add(AttributeValue,Format(AttributeValue.Date,"DF=yyyyMMddHHMMss"));
						Except
							DebuggingErrorText = ErrorDescription();
						EndTry;
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	AttributesList.SortByPresentation();
	MAlreadyInList.Insert(DocumentRef, True);
	
	If AttributesList.Count() = 1 Then
		OutputParentDocuments(AttributesList[0].Value);
	ElsIf AttributesList.Count() > 1 Then
		DisplayWithoutParents(AttributesList);
	EndIf;
	
	TreeRow = MTree.GetItems().Add();
	Query = New Query("SELECT ALLOWED Ref, Posted, DeletionMark, Presentation, #Currency, #Amount, #Comment, """ + DocumentMetadata.Name + """ AS
						   | Metadata FROM Document."+DocumentMetadata.Name + " WHERE Ref = &Ref");
						   
	If DocumentMetadata.Attributes.Find("DocumentCurrency") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Currency", "DocumentCurrency AS DocumentCurrency");
	ElsIf DocumentMetadata.Attributes.Find("CashCurrency") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Currency", "CashCurrency AS DocumentCurrency");
	Else
		Query.Text = StrReplace(Query.Text, "#Currency", "NULL AS DocumentCurrency");
	EndIf;
	
	If DocumentMetadata.Attributes.Find("DocumentAmount") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Amount", "DocumentAmount AS DocumentAmount");
	Else
		Query.Text = StrReplace(Query.Text, "#Amount", "0 AS DocumentAmount");
	EndIf;
	
	If DocumentMetadata.Attributes.Find("Comment") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Comment", "Comment AS Comment");
	ElsIf DocumentMetadata.Attributes.Find("Subject") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "#Comment", 
			"CASE WHEN VALUETYPE(Subject) = Type(Catalog.EventsSubjects) THEN CAST(Subject AS Catalog.EventsSubjects).Description ELSE CAST(Subject AS String) END AS Comment");
	Else
		Query.Text = StrReplace(Query.Text, "#Comment", """"" AS Comment");
	EndIf;
	
	Query.SetParameter("Ref", DocumentRef);
	
	Selection  = Query.Execute().Select();
	If Selection.Next() Then
		TreeRow.Ref = Selection.Ref;
		TreeRow.DocumentPresentation = Selection.Presentation;
		TreeRow.DocumentKind = Selection.Metadata;
		TreeRow.DocumentCurrency = Selection.DocumentCurrency;
		TreeRow.DocumentAmount = Selection.DocumentAmount;
		TreeRow.Comment = ConvertMultilineRow(Selection.Comment);
		TreeRow.Posted = Selection.Posted;
		TreeRow.DeletionMark = Selection.DeletionMark;
		TreeRow.Picture = PictureNumber(TreeRow);
		TreeRow.PostingAllowed = Selection.Ref.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow;
	Else
		TreeRow.Ref = DocumentRef;
		TreeRow.DocumentPresentation = String(DocumentRef);
		TreeRow.DocumentCurrency = Selection.DocumentCurrency;
		TreeRow.DocumentAmount = Selection.DocumentAmount;
		TreeRow.Comment = ConvertMultilineRow(Selection.Comment);
		TreeRow.Posted = Selection.Posted;
		TreeRow.DeletionMark = Selection.DeletionMark;
		TreeRow.Picture = PictureNumber(TreeRow);
		TreeRow.PostingAllowed = DocumentRef.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow;
	EndIf;
	
	MTree = TreeRow;
	
EndProcedure

&AtServer
// Procedure carries out output of the parent documents with restriction on the level in the tree.
//
Procedure DisplayWithoutParents(DocumentsList)
	
	For Each ItemOfList IN DocumentsList Do
		
		DocumentMetadata = ItemOfList.Value.Metadata();
		
		Query = New Query("SELECT ALLOWED Ref, Posted, DeletionMark, Presentation, #Currency, #Amount, #Comment, """ + DocumentMetadata.Name + """ AS
		| Metadata FROM Document."+DocumentMetadata.Name + " WHERE Ref = &Ref");
		
		If DocumentMetadata.Attributes.Find("DocumentCurrency") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Currency", "DocumentCurrency AS DocumentCurrency");
		ElsIf DocumentMetadata.Attributes.Find("CashCurrency") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Currency", "CashCurrency AS DocumentCurrency");
		Else
			Query.Text = StrReplace(Query.Text, "#Currency", "NULL AS DocumentCurrency");
		EndIf;
		
		If DocumentMetadata.Attributes.Find("DocumentAmount") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Amount", "DocumentAmount AS DocumentAmount");
		Else
			Query.Text = StrReplace(Query.Text, "#Amount", "0 AS DocumentAmount");
		EndIf;
		
		If DocumentMetadata.Attributes.Find("Comment") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Comment", "Comment AS Comment");
		ElsIf DocumentMetadata.Attributes.Find("Subject") <> Undefined Then
			Query.Text = StrReplace(Query.Text, "#Comment", 
				"CASE WHEN VALUETYPE(Subject) = Type(Catalog.EventsSubjects) THEN CAST(Subject AS Catalog.EventsSubjects).Description ELSE CAST(Subject AS String) END AS Comment");
		Else
			Query.Text = StrReplace(Query.Text, "#Comment", """"" AS Comment");
		EndIf;
		
		Query.SetParameter("Ref", ItemOfList.Value);
		
		Selection  = Query.Execute().Select();
		If Selection.Next() Then
			If MAlreadyInList[Selection.Ref] = Undefined Then
				TreeRow = MTree.GetItems().Add();
				TreeRow.Ref= Selection.Ref;
				TreeRow.DocumentCurrency= Selection.DocumentCurrency;
				TreeRow.DocumentAmount= Selection.DocumentAmount;
				TreeRow.Comment = ConvertMultilineRow(Selection.Comment);
				TreeRow.DocumentPresentation = Selection.Presentation;
				TreeRow.DocumentKind = Selection.Metadata;
				TreeRow.Posted = Selection.Posted;
				TreeRow.DeletionMark = Selection.DeletionMark;
				TreeRow.RestrictionByParents = True;
				TreeRow.Picture = PictureNumber(TreeRow);
				MAlreadyInList.Insert(Selection.Ref, True);
			EndIf;
		EndIf;
	EndDo;

	MTree = TreeRow;
	
EndProcedure

&AtServer
// Procedure outputs the subordinate documents.
//
Procedure OutputSubordinateDocuments(TreeRow)
	
	CurrentDocument = TreeRow.Ref;
	Table = GetSubordinateDocumentsList(CurrentDocument);
	CacheByDocumentsTypes = New Map;
	
	For Each TableRow IN Table Do
		DocumentMetadata = TableRow.Ref.Metadata();
		If Not AccessRight("Read", DocumentMetadata) Then
			Continue;
		EndIf;
		DocumentName = DocumentMetadata.Name;
		DocumentSynonym = DocumentMetadata.Synonym;
		
		SupplementMetadataCache(DocumentMetadata, DocumentName);
		
		StructureType = CacheByDocumentsTypes[DocumentName];
		If StructureType = Undefined Then
			StructureType = New Structure("Synonym, RefArray", DocumentSynonym, New Array);
			CacheByDocumentsTypes.Insert(DocumentName, StructureType);
		EndIf;
		StructureType.RefArray.Add(TableRow.Ref);
	EndDo;
	
	If CacheByDocumentsTypes.Count() = 0 Then
		Return;
	EndIf;
	
	QueryTextBeginning = "SELECT ALLOWED * FROM (";
	QueryTextEnd = ") AS SubordinateDocuments ORDER BY SubordinateDocuments.Date";
	Query = New Query;
	For Each KeyAndValue IN CacheByDocumentsTypes Do
		Query.Text = Query.Text + ?(Query.Text = "", "
					|SELECT ", "
					|UNION ALL
					|SELECT") + "
					|Date, Ref, Posted, DeletionMark, Presentation, """ + KeyAndValue.Key + """ AS Metadata, #Currency, #Amount, #Comment FROM Document." + KeyAndValue.Key + "
					|WHERE Ref IN (&" + KeyAndValue.Key + ")";
					
		If MDocumentCacheAttributes[KeyAndValue.Key]["DocumentCurrency"] Then
			Query.Text = StrReplace(Query.Text, "#Currency", "DocumentCurrency AS DocumentCurrency");
		ElsIf MDocumentCacheAttributes[KeyAndValue.Key]["CashCurrency"] Then
			Query.Text = StrReplace(Query.Text, "#Currency", "CashCurrency AS DocumentCurrency");
		Else
			Query.Text = StrReplace(Query.Text, "#Currency", "NULL AS DocumentCurrency");
		EndIf;
		
		If MDocumentCacheAttributes[KeyAndValue.Key]["DocumentAmount"] Then
			Query.Text = StrReplace(Query.Text, "#Amount", "DocumentAmount AS DocumentAmount");
		Else
			Query.Text = StrReplace(Query.Text, "#Amount", "0 AS DocumentAmount");
		EndIf;
		
		If MDocumentCacheAttributes[KeyAndValue.Key]["Comment"] Then
			Query.Text = StrReplace(Query.Text, "#Comment", "Comment AS Comment");
		ElsIf MDocumentCacheAttributes[KeyAndValue.Key]["Subject"] Then
			Query.Text = StrReplace(Query.Text, "#Comment", 
				"CASE WHEN VALUETYPE(Subject) = Type(Catalog.EventsSubjects) THEN CAST(Subject AS Catalog.EventsSubjects).Description ELSE CAST(Subject AS String) END AS Comment");
		Else
			Query.Text = StrReplace(Query.Text, "#Comment", """"" AS Comment");
		EndIf;
		
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value.RefArray);
	EndDo;
	
	Query.Text = QueryTextBeginning + Query.Text + QueryTextEnd;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If MAlreadyInList[Selection.Ref] = Undefined Then
			NewRow = TreeRow.GetItems().Add();
			NewRow.Ref = Selection.Ref;
			NewRow.DocumentAmount = Selection.DocumentAmount;
			NewRow.DocumentCurrency = Selection.DocumentCurrency;
			NewRow.Comment = ConvertMultilineRow(Selection.Comment);
			NewRow.DocumentPresentation = Selection.Presentation;
			NewRow.Posted = Selection.Posted;
			NewRow.DeletionMark = Selection.DeletionMark;
			NewRow.Picture = PictureNumber(NewRow);
			MAlreadyInList.Insert(Selection.Ref, True);
			OutputSubordinateDocuments(NewRow);
			NewRow.DocumentKind = Selection.Metadata;
			NewRow.PostingAllowed = Selection.Ref.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow;
		EndIf;
	EndDo;
EndProcedure

&AtClient
// Procedure opens the current document form.
//                                                         
Procedure OpenDocumentForm()
	
	Try
		
		OpeningStructure = New Structure("Key", Items.DocumentsTree.CurrentData.Ref);
		Form = GetForm("Document." + Items.DocumentsTree.CurrentData.DocumentKind + ".ObjectForm", OpeningStructure);
		
		If Items.DocumentsTree.CurrentData.Ref = DocumentRef AND Form.IsOpen() Then
			Message = New UserMessage();
			Message.Text = NStr("en='Document is already opened!';ru='Документ уже открыт!'");
			Message.Message();
		EndIf;
		
		Form.Open();
		
	Except
		
		SmallBusinessServer.ShowMessageAboutError(DocumentRef, ErrorDescription());
		
	EndTry;
	
EndProcedure

&AtServer
// Function searches the subordinate documents of the current document.
//
Function GetSubordinateDocumentsList(BasisDocument) Export
		
	Query = New Query;
	QueryText = "";
	
	For Each ContentItem IN Metadata.FilterCriteria.Dependencies.Content Do
		
		DataPath = ContentItem.FullName();
		StructureDataPath = ParsePathToMetadataObject(DataPath);
		
		If Not AccessRight("Read", StructureDataPath.Metadata) Then
			Continue;
		EndIf;
		
		ObjectName = StructureDataPath.ObjectType + "." + StructureDataPath.ObjectKind;
		
		CurrentRowWHERE = "WHERE " + StructureDataPath.ObjectKind + "." +StructureDataPath.AttributeName + " = &FilterCriterionValue";
			
		TSName = Left(StructureDataPath.AttributeName, Find(StructureDataPath.AttributeName, ".")-1);
		AttributeName = Left(StructureDataPath.AttributeName, Find(StructureDataPath.AttributeName, ".")-1);
		QueryText = QueryText + ?(QueryText = "", "SELECT ALLOWED", "UNION
		|SELECT") + "
		|" + StructureDataPath.ObjectKind +".Ref FROM " + ObjectName + "." + StructureDataPath.TabulSectName + " AS " + StructureDataPath.ObjectKind + "
		|" + StrReplace(CurrentRowWHERE, "..", ".") + "
		|";
		
	EndDo;
	
	Query.Text = QueryText;
	Query.SetParameter("FilterCriterionValue", BasisDocument);
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
// Function returns the path to the metadata object
// MetadataObjectType.DocumentName.TabularSection.TabularSectionName.Attribute.AttributeName.
// MetadataObjectType must be Catalog or Document.
//
// Parameters:
//  DataPath - String.
//
// Returns:
//  Structure - path to metadata object
//
Function ParsePathToMetadataObject(DataPath) Export
	
	Structure = New Structure;
	
	MapOfNames = New Array();
	MapOfNames.Add("ObjectType");
	MapOfNames.Add("ObjectKind");
	MapOfNames.Add("DataPath");
	MapOfNames.Add("TabulSectName");
	MapOfNames.Add("AttributeName");
	
	For index = 1 to 3 Do
		
		Point = Find(DataPath, ".");
		CurrentValue = Left(DataPath, Point-1);
		Structure.Insert(MapOfNames[index-1], CurrentValue);
		DataPath = Mid(DataPath, Point+1);
		
	EndDo;
	
	DataPath = StrReplace(DataPath, "Attribute.", "");
	
	If Structure.DataPath = "TabularSection" Then
		
		For index = 4 to 5  Do 
			
			Point = Find(DataPath, ".");
			If Point = 0 Then
				CurrentValue = DataPath;
			Else
				CurrentValue = Left(DataPath, Point-1);
			EndIf;
			
			Structure.Insert(MapOfNames[index-1], CurrentValue);
			DataPath = Mid(DataPath,  Point+1);
			
		EndDo;
		
	Else
		
		Structure.Insert(MapOfNames[3], "");
		Structure.Insert(MapOfNames[4], DataPath);
		
	EndIf;
	
	If Structure.ObjectType = "Document" Then
		Structure.Insert("Metadata", Metadata.Documents[Structure.ObjectKind]);
	Else
		Structure.Insert("Metadata", Metadata.Catalogs[Structure.ObjectKind]);
	EndIf;
	
	Return Structure;
	
EndFunction // ParsePathToMetadataObject()

&AtClient
// Procedure closes the form with a warning.
//
Procedure CloseFormWithWarning(WarningText)
	
	Raise WarningText;
	
EndProcedure

&AtServer
// Procedure complements the metadata cache.
//
Procedure SupplementMetadataCache(DocumentMetadata, DocumentName)
	
	DocumentAttributes = MDocumentCacheAttributes[DocumentName];
	If DocumentAttributes = Undefined Then
		DocumentAttributes = New Map;
		DocumentAttributes.Insert("DocumentCurrency", DocumentMetadata.Attributes.Find("DocumentCurrency") <> Undefined);
		DocumentAttributes.Insert("CashCurrency", DocumentMetadata.Attributes.Find("CashCurrency") <> Undefined);
		DocumentAttributes.Insert("DocumentAmount", DocumentMetadata.Attributes.Find("DocumentAmount") <> Undefined);
		DocumentAttributes.Insert("Comment", DocumentMetadata.Attributes.Find("Comment") <> Undefined);
		DocumentAttributes.Insert("Subject", DocumentMetadata.Attributes.Find("Subject") <> Undefined);
		MDocumentCacheAttributes.Insert(DocumentName, DocumentAttributes);
	EndIf;
	
EndProcedure

&AtServer
// Function checks the availability of the edited document.
//
Function MainDocumentIsAvailableSofar()
	
	NameCurrentDocument = DocumentRef.Metadata().Name;
	Query = New Query;
	Query.Text = "SELECT ALLOWED Presentation FROM Document." + NameCurrentDocument + " WHERE Ref = &CurrentDocument";
	Query.SetParameter("CurrentDocument", DocumentRef);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtClientAtServerNoContext
// Function returns the picture number.
//
Function PictureNumber(TreeRow)
	
	If TreeRow.DeletionMark Then
		Return 2;
	ElsIf TreeRow.Posted Then
		Return 1;
	Else	
	    Return 0;
	EndIf;
	
EndFunction

&AtClient
// Procedure updates the availability of the Post and Cancel posting buttons.
//
Procedure RefreshButtonsEnabled()
	
	DataCurrentRows = Items.DocumentsTree.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		PropertyValue = Items.DocumentsTree.CurrentData.PostingAllowed;
		
		CommonUseClientServer.SetFormItemProperty(Items, "Post", "Enabled", PropertyValue);
		CommonUseClientServer.SetFormItemProperty(Items, "UndoPosting", "Enabled", PropertyValue);
		
	EndIf;

EndProcedure 

&AtServer
// Function carries out the posting of the selected document.
//
Function PostServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	Try
	    Object.Lock();
		Object.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
		Object.Unlock();
	Except
		Message = New UserMessage();
		Message.Text = NStr("en='Impossible to lock the document';ru='Невозможно заблокировать документ.'");
		Message.Message();
	EndTry; 

	Return Object.Posted;
	
EndFunction

&AtServer
// Function cancels the posting of the selected document.
//
Function UndoPostingServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	Try
	    Object.Lock();
		Object.Write(DocumentWriteMode.UndoPosting);
		Object.Unlock();
	Except
		Message = New UserMessage();
		Message.Text = NStr("en='Impossible to lock the document';ru='Невозможно заблокировать документ.'");
		Message.Message();
	EndTry; 

	Return Object.Posted;
	
EndFunction

&AtServer
// Function marks the selected document for deletion.
//
Function SetDeletionMarkServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	Try
		
		Object.Lock();
		Object.SetDeletionMark(NOT Object.DeletionMark);
		Object.Unlock();
		
	Except
		
		Message = New UserMessage();
		Message.Text = NStr("en='Impossible to lock the document';ru='Невозможно заблокировать документ.'");
		Message.Message();
		
	EndTry; 

	Return New Structure("DeletionMark, Posted", DocumentRef.DeletionMark, DocumentRef.Posted);
	
EndFunction

&AtClientAtServerNoContext
// Function converts a multiline string in a single line.
//
Function ConvertMultilineRow(MultilineString)
	
	RowArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(MultilineString, Chars.LF, True);
	Return StringFunctionsClientServer.RowFromArraySubrows(RowArray, " ");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.DocumentRef = Undefined OR Parameters.DocumentRef.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;

	DocumentRef = Parameters.DocumentRef; 
	
	DisplayDocumentTree();

EndProcedure

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	 
	Items.DocumentsTree.CurrentRow = DocumentsTree.GetItems()[0];

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM ITEMS EVENTS HANDLERS

&AtClient
// Procedure - event handler Before start of changing tabular field DocumentsTree.
//
Procedure DocumentTreeBeforeRowChange(Item, Cancel)	
	OpenDocumentForm();
	Cancel = True;
EndProcedure

&AtClient
// Procedure - action handler Open.
//
Procedure OpenDocument(Command)
	
	If Items.DocumentsTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenDocumentForm();
	
EndProcedure

&AtClient
// Procedure - action handler Refresh.
//
Procedure Refresh(Command)
	
	If MainDocumentIsAvailableSofar() Then
		DisplayDocumentTree(); 
	Else
		CloseFormWithWarning(NStr("en='The document, for which the report
		|on the hierarchy structure was generated, is deleted or not available.';ru='Документ, для которого сформирован
		|отчет о структуре подчиненности был удален, или же стал недоступен.'"));
	EndIf;		
	
	
EndProcedure

&AtClient
// Procedure - action handler OutputForCurrent.
//
Procedure OutputForCurrent(Command)	
	
	If Items.DocumentsTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	DocumentRef = Items.DocumentsTree.CurrentData.Ref;
	If MainDocumentIsAvailableSofar() Then
		DocumentsTree.GetItems().Clear();	
		DisplayDocumentTree();
	Else
		CloseFormWithWarning(NStr("en='The document, for which the report
		|on the hierarchy structure was generated, is deleted or not available.';ru='Документ, для которого сформирован
		|отчет о структуре подчиненности был удален, или же стал недоступен.'"));
	EndIf;
		
EndProcedure

&AtClient
// Procedure - action handler FindInList.
//
Procedure FindInList(Command)
	
	If Items.DocumentsTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Try
		OpenForm("Document."+Items.DocumentsTree.CurrentData.DocumentKind + ".ListForm", New Structure("CurrentRow", Items.DocumentsTree.CurrentData.Ref));
	Except
		SmallBusinessServer.ShowMessageAboutError(DocumentRef, ErrorDescription());
	EndTry;
	
EndProcedure

&AtClient
// Procedure - action handler Post.
//
Procedure Post(Button)
		
	If Items.DocumentsTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Try       
		Items.DocumentsTree.CurrentData.Posted = PostServer(Items.DocumentsTree.CurrentData.Ref);
		Items.DocumentsTree.CurrentData.Picture = PictureNumber(Items.DocumentsTree.CurrentData);
	Except
		
		Message = New UserMessage();
		Message.Text = NStr("en='Failed to post the document %Document%!';ru='Не удалось провести документ %Document%!'");;
		Message.Text = StrReplace(Message.Text, "%Document%", Items.DocumentsTree.CurrentData.DocumentPresentation);
		Message.Message();
		
	EndTry;
	
EndProcedure

&AtClient
// Procedure - action handler Cancel of the posting.
//
Procedure UndoPosting(Button)
		
	If Items.DocumentsTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not Items.DocumentsTree.CurrentData.Posted Then
		Return;
	EndIf;
	
	Try
		Items.DocumentsTree.CurrentData.Posted = UndoPostingServer(Items.DocumentsTree.CurrentData.Ref);
		Items.DocumentsTree.CurrentData.Picture = PictureNumber(Items.DocumentsTree.CurrentData);
	Except
		
		Message = New UserMessage();
		Message.Text = NStr("en='Failed to make the document %Document% unposted!';ru='Не удалось сделать непроведенным документ %Документ%!'");;
		Message.Text = StrReplace(Message.Text, "%Document%", Items.DocumentsTree.CurrentData.DocumentPresentation);
		Message.Message();
		
	EndTry;
	
EndProcedure

&AtClient
// Procedure - event handler OnActivateRow of the DocumentsTree attribute.
//
Procedure DocumentTreeOnActivateRow(Item)
	RefreshButtonsEnabled();	
EndProcedure

&AtClient
// Procedure - action handler SetDeletionMark.
//
Procedure SetDeletionMark(Button)
	
	CurrentRowData = Items.DocumentsTree.CurrentData;
	If CurrentRowData = Undefined Then
		Return;
	EndIf;
	
	Try
		
		Result = SetDeletionMarkServer(CurrentRowData.Ref);
		CurrentRowData.DeletionMark = Result.DeletionMark;
		CurrentRowData.Posted		= Result.Posted;
		CurrentRowData.Picture		= PictureNumber(CurrentRowData);
		RefreshButtonsEnabled();
		
	Except
		
		Message = New UserMessage();
		Message.Text = NStr("en='Failed to mark the %Document% document for deletion!';ru='Не удалось установить пометку удаления на документ %Document%!'");;
		Message.Text = StrReplace(Message.Text, "%Document%", CurrentRowData.DocumentPresentation);
		Message.Message();
		
	EndTry;
	
EndProcedure

&AtClient
// Procedure - action handler Choice of the document tree.
//
Procedure DocumentTreeSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.DocumentsTree.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenDocumentForm();
	
EndProcedure
