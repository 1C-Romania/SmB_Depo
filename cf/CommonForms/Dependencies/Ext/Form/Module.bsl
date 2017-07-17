////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Parameters.Property("FilterObject", DocumentRef);
	
	InitialDocument = DocumentRef;
	
	If ValueIsFilled(DocumentRef) Then
		RefreshTreeStructureOfSubjection();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	//ReportTable.Show();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Refresh(Command)
	
	OutputStructureOfSubordinance();
	//ReportTable.Show();
	
EndProcedure

&AtClient
Procedure OutputForCurrent(Command)
	
	CurrentDocument = Items.ReportTable.CurrentArea.Details;
	
	If ValueIsFilled(CurrentDocument) Then
		DocumentRef = CurrentDocument;
	Else
		Return;
	EndIf;
	
	OutputStructureOfSubordinance();
	//ReportTable.Show();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

//////////////////////////////////////////////////////////////////////////////////////////////
// Tabular document output procedures.

// It outputs the subordination tree to tabular document
&AtServer
Procedure DisplayTableDocument()

	ReportTable.Clear();
	
	Template = GetCommonTemplate("Dependencies");
	
	OutputParentTreeItems(TreeParentDocuments.GetItems(),Template,1);
	PutCurrentDocument(Template);
	DisplaySubordinatedTreeNodes(TreeSlaveDocuments.GetItems(),Template,1)
	
EndProcedure

// It outputs the tree rows of parent documents
//
// Parameters:
//  TreeRows  - FormDataTreeItemCollection - tree
//                 rows that are output to
//  the Template tabular document  - TemplateTableDocument - template on
//           the basis of which the
//  data is output to the RecursionLevel tabular document - Number - recursion procedure level
//
&AtServer
Procedure OutputParentTreeItems(TreeRows,Template,RecursionLevel)
	
	Counter =  TreeRows.Count();
	While Counter >0 Do
		
		CurrentTreeRow = TreeRows.Get(Counter -1);
		SuborderedItemsTreeRows = CurrentTreeRow.GetItems();
		OutputParentTreeItems(SuborderedItemsTreeRows,Template,RecursionLevel + 1);
		
		For ind=1 To RecursionLevel Do
			
			If ind = RecursionLevel Then
				
				If TreeRows.IndexOf(CurrentTreeRow) < (TreeRows.Count()-1) Then
					Area = Template.GetArea("ConnectorTopRightBottom");
				Else	
					Area = Template.GetArea("ConnectorRightBottom");
				EndIf;
				
			Else
				
				If NecessityOfVerticalConnectorOutput(RecursionLevel - ind + 1,CurrentTreeRow,False) Then
					Area = Template.GetArea("ConnectorTopBottom");
				Else
					Area = Template.GetArea("Indent");
					
				EndIf;
				
			EndIf;
			
			If ind = 1 Then
				ReportTable.Put(Area);
			Else
				ReportTable.Join(Area);
			EndIf;
			
		EndDo;
		
		DisplayDocumentAndPicture(CurrentTreeRow,Template,False,False);

		Counter = Counter - 1;
		
	EndDo;
	
EndProcedure

// Outputs an image that corresponds to the document status and its presentation to the tabular document.
//
&AtServer
Procedure DisplayDocumentAndPicture(TreeRow,Template,IsCurrentDocument = False,IsSubordinated = Undefined)
	
	//Image output
	If TreeRow.Posted Then
		If IsSubordinated = Undefined  Then
			If TreeSlaveDocuments.GetItems().Count() AND TreeParentDocuments.GetItems().Count()  Then
				AreaPicture = Template.GetArea("DocumentPostedConnectorTopBottom");
			ElsIf TreeSlaveDocuments.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentPostedConnectorBottom");
			ElsIf TreeParentDocuments.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentPostedConnectorTop");
			Else
				AreaPicture = Template.GetArea("DocumentPostedConnectorTop");
			EndIf;
		ElsIf IsSubordinated = True Then
			If TreeRow.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentPostedConnectorLeftBottom");
			Else
				AreaPicture = Template.GetArea("DocumentPosted");
			EndIf;
		Else
			If TreeRow.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentPostedConnectorLeftTop");
			Else
				AreaPicture = Template.GetArea("DocumentPosted");
			EndIf;
		EndIf;
	ElsIf TreeRow.DeletionMark Then
		If IsSubordinated = Undefined Then
			If TreeSlaveDocuments.GetItems().Count() AND TreeParentDocuments.GetItems().Count()  Then
				AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorTopBottom");
			ElsIf TreeSlaveDocuments.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorBottom");
			ElsIf TreeParentDocuments.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorTop");
			Else
				AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorTop");
			EndIf;
		ElsIf IsSubordinated = True Then
			If TreeRow.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorLeftBottom");
			Else
				AreaPicture = Template.GetArea("DocumentIsMarkedForDeletion");
			EndIf;
		Else
			If TreeRow.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorLeftTop");
			Else
				AreaPicture = Template.GetArea("DocumentIsMarkedForDeletion");
			EndIf;
		EndIf;
	Else
		If TreeRow.Ref = DocumentRef Then
			If TreeSlaveDocuments.GetItems().Count() AND TreeParentDocuments.GetItems().Count()  Then
				AreaPicture = Template.GetArea("DocumentWrittenConnectorTopBottom");
			ElsIf TreeSlaveDocuments.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentWrittenConnectorDown");
			ElsIf TreeParentDocuments.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentWrittenConnectorTop");
			Else
				AreaPicture = Template.GetArea("DocumentWrittenConnectorTop");
			EndIf;
		ElsIf IsSubordinated = True Then
			If TreeRow.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentWrittenConnectorLeftBottom");
			Else
				AreaPicture = Template.GetArea("DocumentRecorded");
			EndIf;
		Else
			If TreeRow.GetItems().Count() Then
				AreaPicture = Template.GetArea("DocumentWrittenConnectorLeftTop");
			Else
				AreaPicture = Template.GetArea("DocumentRecorded");
			EndIf;
		EndIf;
	EndIf;
	If IsCurrentDocument Then
		ReportTable.Put(AreaPicture) 
	Else
		ReportTable.Join(AreaPicture);
	EndIf;
	
	
	//Document output
	AreaDocument = Template.GetArea(?(IsCurrentDocument,"CurrentDocument","Document"));
	AreaDocument.Parameters.DocumentPresentation = TreeRow.Presentation;
	AreaDocument.Parameters.Document = TreeRow.Ref;
	ReportTable.Join(AreaDocument);
	
EndProcedure

// Determines whether it is required to output a vertical connector to the tabular document
//
// Parameters:
//  LevelUp  - Number - at what number of levels above
//  is placed the parent which will be drawn the TreeRow vertical
//  connector from  - FormDataTreeItem - original value
//                  tree row which the count is taking from.
// Returns:
//   Boolean   - flag showing that output in the vertical connector area is required.
//
&AtServer
Function NecessityOfVerticalConnectorOutput(LevelUp,TreeRow,LookAmongSubordinates = True)
	
	CurrentRow = TreeRow;
	
	For ind=1 To LevelUp Do
		
		CurrentRow = CurrentRow.GetParent();
		If ind = LevelUp Then
			ParentToFind = CurrentRow;
		ElsIf ind = (LevelUp-1) Then
			RowToFind = CurrentRow;
		EndIf;
		
	EndDo;
	
	If ParentToFind = Undefined Then
		If LookAmongSubordinates Then
			ParentSubordinateNodes =  TreeSlaveDocuments.GetItems(); 
		Else
			ParentSubordinateNodes =  TreeParentDocuments.GetItems();
		EndIf;
	Else
		ParentSubordinateNodes =  ParentToFind.GetItems(); 
	EndIf;
	
	Return ParentSubordinateNodes.IndexOf(RowToFind) < (ParentSubordinateNodes.Count()-1);
	
EndFunction

// Displays in the tabular document the row with the document for which the subordination structure is formed
//
// Parameters:
//  Template  - TemplateTableDocument - template on the basis of which the tabular document is formed.
&AtServer
Procedure PutCurrentDocument(Template)
	
	Selection = GetSelectionByDocumentAttributes(DocumentRef);
	If Selection.Next() Then
		
		OverridablePresentation = DependenciesOverridable.GetDocumentPresentationToPrint(Selection);
		
		If OverridablePresentation <> Undefined Then
			AttributesStructure = CommonUse.ValueTableRowToStructure(Selection.Owner().Unload()[0]);
			AttributesStructure.Presentation = OverridablePresentation;
			DisplayDocumentAndPicture(AttributesStructure,Template,True);
		Else
			AttributesStructure = CommonUse.ValueTableRowToStructure(Selection.Owner().Unload()[0]);
			AttributesStructure.Presentation = GetDocumentPresentationToPrint(AttributesStructure);
			DisplayDocumentAndPicture(AttributesStructure,Template,True);
		EndIf;
		
	EndIf;
	
EndProcedure

// It forms the document presentation for output to tabular document
//
// Parameters:
//  Selection  - QueryResultSelection or FormDataTreeItem - Dataset
//             on the basis of which presentation is formed
//
// Returns:
//   String   - generated presentation.
//
&AtServer
Function GetDocumentPresentationToPrint(Selection)
	
	DocumentPresentation = Selection.Presentation;
	If (Selection.DocumentAmount <> 0) AND (Selection.DocumentAmount <> NULL) Then
		DocumentPresentation = DocumentPresentation + " " + NStr("en='to the amount of';ru='на сумму'") + " " + Selection.DocumentAmount + " " + Selection.Currency + ".";
	EndIf;
	
	Return DocumentPresentation;
	
EndFunction

// It displays the tree rows of subordinate documents
//
// Parameters:
//  TreeRows  - FormDataTreeItemCollection - tree
//                 rows that are output to
//  the Template tabular document  - TemplateTableDocument - template on
//                 the basis of which the
//  data is output to the RecursionLevel tabular document - Number - recursion procedure level
//
&AtServer
Procedure DisplaySubordinatedTreeNodes(TreeRows,Template,RecursionLevel)

	For Each TreeRow IN TreeRows Do
		
		IsCurrentDocument = (TreeRow.Ref = DocumentRef);
		IsInitialDocument = (TreeRow.Ref = InitialDocument);
		SubordinatedTreeNodes = TreeRow.GetItems();
		
		//Connector output
		For ind = 1 To RecursionLevel Do
			If RecursionLevel > ind Then
				
				If NecessityOfVerticalConnectorOutput(RecursionLevel - ind + 1,TreeRow) Then
					Area = Template.GetArea("ConnectorTopBottom");
				Else
					Area = Template.GetArea("Indent");
					
				EndIf;
			Else 
				
				If TreeRows.Count() > 1 AND (TreeRows.IndexOf(TreeRow)<> (TreeRows.Count()-1)) Then
					Area = Template.GetArea("ConnectorTopRightBottom");
				Else
					Area = Template.GetArea("ConnectorTopRight");
				EndIf;
				
			EndIf;	
			
			Area.Parameters.Document = ?(IsInitialDocument,Undefined,TreeRow.Ref);
			
			If ind = 1 Then
				ReportTable.Put(Area);
			Else
				ReportTable.Join(Area);
			EndIf;
			
		EndDo;		
		
		DisplayDocumentAndPicture(TreeRow,Template,False,True);
		
		//Subordinate tree items output
		DisplaySubordinatedTreeNodes(SubordinatedTreeNodes,Template,RecursionLevel + 1);
		
	EndDo;
	
EndProcedure

//Initiates the output to tabular document and displays it at the formation end.
&AtClient
Procedure OutputStructureOfSubordinance()

	RefreshTreeStructureOfSubjection();
	//ReportTable.Show();

EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////
// Procedure of the document subordination tree building.

&AtServer
Procedure RefreshTreeStructureOfSubjection()

	If MainDocumentAvailable() Then
		GenerateDocumentsTrees();
		DisplayTableDocument();
	Else
		CommonUseClientServer.MessageToUser(
			NStr("en='The document for which the dependence structure report is generated is no longer available.';ru='Документ, для которого сформирован отчет о структуре подчиненности, стал недоступен.'"));
	EndIf;

EndProcedure

&AtServer
Procedure GenerateDocumentsTrees()

	TreeParentDocuments.GetItems().Clear();
	TreeSlaveDocuments.GetItems().Clear();

	OutputParentDocuments(DocumentRef,TreeParentDocuments);
	OutputSubordinateDocuments(DocumentRef,TreeSlaveDocuments);

EndProcedure

&AtServer
Function MainDocumentAvailable()

	Query = New Query(
	"SELECT ALLOWED
	|	1
	|FROM
	|	Document." + DocumentRef.Metadata().Name + " AS
	|Tab
	|WHERE Tab.Ref = &CurrentDocument
	|");
	Query.SetParameter("CurrentDocument", DocumentRef);
	Return Not Query.Execute().IsEmpty();

EndFunction

// It gets the document attributes sample
//
// Parameters:
//  DocumentRef  - DocumentRef - document which attribute values are received by the query.
//
// Returns:
//   QueryResultSelection
//
&AtServer
Function GetSelectionByDocumentAttributes(DocumentRef)
	
	DocumentMetadata = DocumentRef.Metadata();
	
	QueryText = 
	"SELECT ALLOWED
	|	Ref,
	|	Posted,
	|	DeletionMark,
	|	#Amount,
	|	#Currency,
	|	#Presentation
	|FROM
	|	Document." + DocumentMetadata.Name + "
	|WHERE
	|	Ref = &Ref
	|";
	ReplaceQueryText(QueryText, DocumentMetadata, "#Amount", "DocumentAmount");
	ReplaceQueryTextCurrency(QueryText, DocumentMetadata, "#Currency", "Currency"); // SB
	
	AdditAttributesArray = DependenciesOverridable.ArrayAdditionalDocumentAttributes(DocumentMetadata.Name);
	
	AddQueryTextByAttributesDocument(QueryText, AdditAttributesArray);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", DocumentRef);
	Return Query.Execute().Select(); 
	
EndFunction

&AtServer
Procedure OutputParentDocuments(CurrentDocument,ParentalTree)

	TreeRows = ParentalTree.GetItems();
	DocumentMetadata = CurrentDocument.Metadata();
	AttributesList    = New ValueList;
	
	For Each Attribute IN DocumentMetadata.Attributes Do
		
		If Metadata.FilterCriteria.RelatedDocuments.Content.Contains(Attribute) Then
			
			For Each CurrentType IN Attribute.Type.Types() Do
				
				AttributeMetadata = Metadata.FindByType(CurrentType);
				
				If AttributeMetadata <> Undefined
					AND Metadata.Documents.Contains(AttributeMetadata)
					AND AccessRight("Read", AttributeMetadata) Then
					
					AttributeValue = CurrentDocument[Attribute.Name];
					
					If ValueIsFilled(AttributeValue)
						AND TypeOf(AttributeValue) = CurrentType
						AND AttributeValue <> CurrentDocument
						AND AttributesList.FindByValue(AttributeValue) = Undefined Then
						
						AttributesList.Add(AttributeValue,Format(AttributeValue.Date,"DF=yyyyMMddHHMMss"));
						
					EndIf;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;

	For Each CWT IN DocumentMetadata.TabularSections Do
		PageAttributes = "";

		TSContent = CurrentDocument[CWT.Name].Unload();

		For Each Attribute IN CWT.Attributes Do

			If Metadata.FilterCriteria.RelatedDocuments.Content.Contains(Attribute) Then
				
				For Each CurrentType IN Attribute.Type.Types() Do
					
					AttributeMetadata = Metadata.FindByType(CurrentType);
					
					If AttributeMetadata<>Undefined
						AND Metadata.Documents.Contains(AttributeMetadata)
						AND AccessRight("Read", AttributeMetadata) Then
						
						PageAttributes = PageAttributes + ?(PageAttributes = "", "", ", ") + Attribute.Name;
						Break;
						
					EndIf;
				EndDo;
				
			EndIf;
			
		EndDo;

		TSContent.GroupBy(PageAttributes);
		For Each ColumnTS IN TSContent.Columns Do

			For Each TSRow IN TSContent Do

				AttributeValue = TSRow[ColumnTS.Name];

				ValueMetadata = Metadata.FindByType(TypeOf(AttributeValue));
				If ValueMetadata <> Undefined Then

					If ValueIsFilled(AttributeValue)
						AND Metadata.Documents.Contains(ValueMetadata)
						AND AttributeValue <> CurrentDocument
						AND AttributesList.FindByValue(AttributeValue) = Undefined Then

							AttributesList.Add(AttributeValue,Format(AttributeValue.Date,"DF=yyyyMMddHHMMss"));

					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndDo;

	AttributesList.SortByPresentation();
	
	For Each ItemOfList IN AttributesList Do
		
		Selection = GetSelectionByDocumentAttributes(ItemOfList.Value);
		
		If Selection.Next() Then
			TreeRow = AddRowToTree(TreeRows, Selection);
			If Not AddedDocumentIsAmongParents(ParentalTree,ItemOfList.Value) Then
				OutputParentDocuments(ItemOfList.Value,TreeRow);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

// Determines the document existence among the tree row parents that might be added
//
// Parameters:
//  ParentRow  - FormDataTree,FormDataTreeItem - is a
// parent which it is assumed to add a tree row for.
//  DocumentRef  - Document - document which existence is being checked
//
// Returns:
//   Boolean   - True if it is found, otherwise, False.
//
Function AddedDocumentIsAmongParents(ParentRow,RequiredDocument)
	
	If RequiredDocument = DocumentRef Then
		Return True;
	EndIf;
	
	If TypeOf(ParentRow) = Type("FormDataTree") Then
		Return False; 
	EndIf;
	
	CurrentParent = ParentRow;
	While CurrentParent <> Undefined Do
		If CurrentParent.Ref = RequiredDocument Then
		    Return True;
		EndIf;
		CurrentParent = CurrentParent.GetParent();
	EndDo;
	
	Return False;
	
EndFunction


&AtServer
Procedure ReplaceQueryText(QueryText, DocumentMetadata, ReplaceTarget, AttributeName)

	If DocumentMetadata.Attributes.Find(AttributeName) <> Undefined Then
		QueryText = StrReplace(QueryText, ReplaceTarget, AttributeName + " AS " + AttributeName);
	Else
		QueryText = StrReplace(QueryText, ReplaceTarget, " NULL AS " + AttributeName);
	EndIf;

EndProcedure

&AtServer
Procedure SupplementMetadataCache(DocumentMetadata, DocumentName,DocumentAttributesCache)

	DocumentAttributes = DocumentAttributesCache[DocumentName];
	If DocumentAttributes = Undefined Then

		DocumentAttributes = New Map;
		DocumentAttributes.Insert("DocumentAmount",  DocumentMetadata.Attributes.Find("DocumentAmount") <> Undefined);
		
		// SB
		If DocumentMetadata.Attributes.Find("Currency") <> Undefined Then
			
			DocumentAttributes.Insert("Currency", True);
			
		ElsIf DocumentMetadata.Attributes.Find("DocumentCurrency") <> Undefined Then
			
			DocumentAttributes.Insert("DocumentCurrency", True);
			
		ElsIf DocumentMetadata.Attributes.Find("CashCurrency") <> Undefined Then
			
			DocumentAttributes.Insert("CashCurrency", True);
			
		EndIf;
		// End. SB
		
		DocumentAttributesCache.Insert(DocumentName, DocumentAttributes);

	EndIf;
	
EndProcedure


&AtServer
Function GetDocumentsListOnFilterCriterion(ValueOfFilterCriterion)
	
	If Metadata.FilterCriteria.RelatedDocuments.Type.ContainsType(TypeOf(ValueOfFilterCriterion))  Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	RelatedDocuments.Ref
		|FROM
		|	FilterCriterion.RelatedDocuments(&ValueOfFilterCriterion) AS RelatedDocuments";
		
		Query.SetParameter("ValueOfFilterCriterion",ValueOfFilterCriterion);
		Return Query.Execute().Unload();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

&AtServer
Procedure OutputSubordinateDocuments(CurrentDocument,ParentalTree)
	
	TreeRows = ParentalTree.GetItems();
	Table      = GetDocumentsListOnFilterCriterion(CurrentDocument);
	If Table = Undefined Then
		Return;
	EndIf;

	CacheByDocumentsTypes   = New Map;
	DocumentAttributesCache = New Map;

	For Each TableRow IN Table Do

		DocumentMetadata = TableRow.Ref.Metadata();
		If Not AccessRight("Read", DocumentMetadata) Then
			Continue;
		EndIf;

		DocumentName = DocumentMetadata.Name;
		SupplementMetadataCache(DocumentMetadata, DocumentName,DocumentAttributesCache);

		RefArray = CacheByDocumentsTypes[DocumentName];
		If RefArray = Undefined Then

			RefArray = New Array;
			CacheByDocumentsTypes.Insert(DocumentName, RefArray);

		EndIf;

		RefArray.Add(TableRow.Ref);

	EndDo;
	
	If CacheByDocumentsTypes.Count() = 0 THEN
		Return;
	EndIf;

	QueryTextBeginning = "SELECT ALLOWED * FROM (";
	QueryTextEnd = ") AS SubordinatedDocuments ORDER BY SubordinatedDocuments.Date";

	Query = New Query;
	QueryText = "";
	For Each KeyAndValue IN CacheByDocumentsTypes Do

		TextByDocumentType = "
		|	Date,
		|	Ref,
		|	Posted,
		|	DeletionMark,
		|	" + ?(DocumentAttributesCache[KeyAndValue.Key]["DocumentAmount"], "DocumentAmount", "NULL") + " AS DocumentAmount,
		|	&Currency AS Currency,
		|	#Presentation
		|FROM
		|	Document." + KeyAndValue.Key + "
		|	WHERE Ref IN (&" + KeyAndValue.Key + ")";
		
		// SB
		If DocumentAttributesCache[KeyAndValue.Key].Get("Currency") <> Undefined Then
			TextByDocumentType = StrReplace(TextByDocumentType, "&Currency", "Currency");
		ElsIf DocumentAttributesCache[KeyAndValue.Key].Get("DocumentCurrency") <> Undefined Then
			TextByDocumentType = StrReplace(TextByDocumentType, "&Currency", "DocumentCurrency");
		ElsIf DocumentAttributesCache[KeyAndValue.Key].Get("CashCurrency") <> Undefined Then
			TextByDocumentType = StrReplace(TextByDocumentType, "&Currency", "CashCurrency");
		Else
			TextByDocumentType = StrReplace(TextByDocumentType, "&Currency", "Null");
		EndIf;
		// SB End
		
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
		
		AdditAttributesArray = DependenciesOverridable.ArrayAdditionalDocumentAttributes(KeyAndValue.Key);
		AddQueryTextByAttributesDocument(TextByDocumentType, AdditAttributesArray);
		
		QueryText = QueryText + ?(QueryText = "", " SELECT ", " UNION ALL SELECT ") + TextByDocumentType;

	EndDo;

	Query.Text = QueryTextBeginning + QueryText + QueryTextEnd;
	Selection = Query.Execute().Select();

	While Selection.Next() Do
		
		NewRow = AddRowToTree(TreeRows, Selection);
		If Not AddedDocumentIsAmongParents(ParentalTree,Selection.Ref) Then
			OutputSubordinateDocuments(Selection.Ref,NewRow)
		EndIf;
		
	EndDo;

EndProcedure

&AtServer
Function AddRowToTree(TreeRows, Selection)

	NewRow = TreeRows.Add();
	FillPropertyValues(NewRow, Selection, "Ref, Presentation, DocumentAmount, Currency, Posted, DeletionMark");
	
	OverriddenPresentation = DependenciesOverridable.GetDocumentPresentationToPrint(Selection);
	If OverriddenPresentation <> Undefined Then
		NewRow.Presentation = OverriddenPresentation;
	Else
		NewRow.Presentation = GetDocumentPresentationToPrint(Selection);
	EndIf;
	
	Return NewRow;

EndFunction

&AtServer
Procedure AddQueryTextByAttributesDocument(QueryText, AttributeArray)
	
	TextPresentation = "Presentation AS Presentation";
	
	For Ind = 1 To 3 Do
		
		TextPresentation = TextPresentation + ",
			                   |	" + ?(AttributeArray.Count() >= Ind,AttributeArray[ind - 1],"NULL") + " As AdditionalAttribute" + Ind;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "#Presentation", TextPresentation);
	
EndProcedure


//////////////////////////////////////////////////////////////////////////////////////////////
// SB PROCEDURES  AND FUNCTIONS

// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
// Function posts the selected document.
//
Function PostDocumentAtServer(DocumentRef)
	
	If DocumentRef.DeletionMark Then
		
		Return NStr("en='Document marked for deletion cannot be posted.';ru='Помеченный на удаление документ не может быть проведен!'");
		
	EndIf;
	
	Object = DocumentRef.GetObject();
	
	Try
		
		Object.Lock();
		
	Except
		
		ErrorText = NStr("en='Action (posting) cannot be performed as the %1 document is locked by the user.';ru='Действие (проведение) не может быть выполнено, так как документ %1 заблокирован пользователем!'");
		Return StringFunctionsClientServer.SubstituteParametersInString(ErrorText, DocumentRef);
		
	EndTry;
	
	Object.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
	Object.Unlock();
	
	Return "";
	
EndFunction

&AtServer
// Function cancels the posting of the selected document
//
Function UndoPostingDocumentAtServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	
	Try
		
		Object.Lock();
		
	Except
		
		ErrorText = NStr("en='Action (posting cancellation) cannot be performed as the %1 document is locked by the user.';ru='Действие (отмена проведения) не может быть выполнено, так как документ %1 заблокирован пользователем!'");
		Return StringFunctionsClientServer.SubstituteParametersInString(ErrorText, DocumentRef);
		
	EndTry;
	
	Object.Write(DocumentWriteMode.UndoPosting);
	Object.Unlock();

	Return "";
	
EndFunction // UndoPostingDocumentAtServer()

&AtServer
// Function marks for deletion of the selected document.
//
Function SetDeletionMarkOfDocumentAtServer(DocumentRef)
	
	Object = DocumentRef.GetObject();
	
	Try
		
		Object.Lock();
		
	Except
		
		ErrorText = NStr("en='Action (set / clear deletion mark) cannot be performed as the %1 document is locked by the user.';ru='Действие (установить / снять пометку удаления) не может быть выполнено, так как документ %1 заблокирован пользователем!'");
		Return StringFunctionsClientServer.SubstituteParametersInString(ErrorText, DocumentRef);
		
	EndTry;
	
	Object.SetDeletionMark(NOT Object.DeletionMark);
	Object.Unlock();
	
	Return "";
	
EndFunction

&AtServerNoContext
// The function returns the document name from metadata by its ref
//
Function GetDocumentKindAtServer(DocumentRef)
	
	Return DocumentRef.Metadata().Name;
	
EndFunction // GetDocumentKindAtServer()

&AtServer
Procedure ReplaceQueryTextCurrency(QueryText, DocumentMetadata, ReplaceTarget, AttributeName)
	
	If DocumentMetadata.Attributes.Find("DocumentCurrency") <> Undefined Then
		
		QueryText = StrReplace(QueryText, "#Currency", "DocumentCurrency AS Currency");
		
	ElsIf DocumentMetadata.Attributes.Find("CashCurrency") <> Undefined Then
		
		QueryText = StrReplace(QueryText, "#Currency", "CashCurrency AS Currency");
		
	Else
		
		QueryText = StrReplace(QueryText, "#Currency", "NULL  AS Currency");
		
	EndIf;
	
EndProcedure

// FORM COMMAND HANDLERS

&AtClient
// Procedure - the PostDocument command handler
//
Procedure PostDocument(Command)
	
	CurrentDocument = Items.ReportTable.CurrentArea.Details;
	
	If ValueIsFilled(CurrentDocument) Then
		
		Try
			
			ErrorText = PostDocumentAtServer(CurrentDocument);
			
			If IsBlankString(ErrorText) Then
				
				OutputStructureOfSubordinance();
				//ReportTable.Show();
				
			EndIf;
			
		Except
			
			ErrorText = NStr("en='Cannot post the %1 document.';ru='Не удалось провести документ %1!'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CurrentDocument)
			
		EndTry;
		
		If Not IsBlankString(ErrorText) Then
			
			CommonUseClientServer.MessageToUser(ErrorText);
			
		EndIf;
		
	EndIf;
	
EndProcedure // PostDocument()

// Procedure - the UndoPostingDocument command handler
//
&AtClient
Procedure UndoPostingDocument(Command)
	
	CurrentDocument = Items.ReportTable.CurrentArea.Details;
	
	If ValueIsFilled(CurrentDocument) Then
		
		Try
			
			ErrorText = UndoPostingDocumentAtServer(CurrentDocument);
			
			OutputStructureOfSubordinance();
			//ReportTable.Show();
			
		Except
			
			ErrorText = NStr("en='Cannot cancel the %1 document posting.';ru='Не удалось отменить проведение документа %1!'");;
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CurrentDocument);
			
		EndTry;
		
		If Not IsBlankString(ErrorText) Then
			
			CommonUseClientServer.MessageToUser(ErrorText);
			
		EndIf;
		
	EndIf;
	
EndProcedure // UndoPostingDocument()

&AtClient
// Procedure - the SetDeletionMarkDocument command handler
//
Procedure SetDeletionMarkDocument(Command)
	
	CurrentDocument = Items.ReportTable.CurrentArea.Details;
	
	If ValueIsFilled(CurrentDocument) Then
		
		Try
			
			ErrorText = SetDeletionMarkOfDocumentAtServer(CurrentDocument);
			
			OutputStructureOfSubordinance();
			//ReportTable.Show();
			
		Except
			
			ErrorText = NStr("en='Cannot set the deletion mark for document %1.';ru='Не удалось установить пометку удаления на документ %1!'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CurrentDocument);
			
		EndTry;
		
		If Not IsBlankString(ErrorText) Then
			
			CommonUseClientServer.MessageToUser(ErrorText);
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetDeletionMarkDocument()

&AtClient
// Procedure - the OpenDocument command handler
//
Procedure OpenDocument(Command)
	
	CurrentDocument = Items.ReportTable.CurrentArea.Details;
	
	If ValueIsFilled(CurrentDocument) Then
		
		Try
			
			OpeningStructure = New Structure("Key", CurrentDocument);
			Form = GetForm("Document." + GetDocumentKindAtServer(CurrentDocument) + ".ObjectForm", OpeningStructure);
			
			If Form.IsOpen() Then
				
				ErrorText = NStr("en='Document is already opened.';ru='Документ уже открыт!'");
				CommonUseClientServer.MessageToUser(
						StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CurrentDocument)
						);
				
			Else
				
				Form.Open();
				
			EndIf;
			
		Except
			
			ErrorText = NStr("en='Failed to open the %1 document.';ru='Не удалось открыть документ %1!'");
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CurrentDocument)
				);
			
		EndTry;
		
	EndIf;
	
EndProcedure // OpenDocument()

&AtClient
// Procedure - the FindInList command handler
//
Procedure FindInList(Command)
	
	CurrentDocument = Items.ReportTable.CurrentArea.Details;
	
	If Not ValueIsFilled(CurrentDocument) Then
		
		Return;
		
	EndIf;
	
	Try
		
		ListForm = GetForm("Document." + GetDocumentKindAtServer(CurrentDocument) + ".ListForm");
		ListForm.Open();
		ListForm.Items.List.CurrentRow = CurrentDocument;
		
	Except
		
		ErrorText = NStr("en='Cannot open the %1 document in the list.';ru='Не удалось открыть в списке документ %1!'");
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CurrentDocument)
			);
		
	EndTry;
	
EndProcedure // FindInList()
