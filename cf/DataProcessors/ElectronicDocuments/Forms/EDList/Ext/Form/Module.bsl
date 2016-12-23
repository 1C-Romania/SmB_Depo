////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure UpdateEDDependenciesTree()
	
	SetPrivilegedMode(True);
	
	ExchangeSettings = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(ObjectRef, False);
	If Not ValueIsFilled(ExchangeSettings) Then
		SignatureRequired = False;
	Else
		SignatureRequired = ExchangeSettings.ToSign;
		EDFSetup = ExchangeSettings.EDAgreement;
		
		If ValueIsFilled(EDFSetup)
			AND CommonUse.ObjectAttributeValue(EDFSetup, "BankApplication") = Enums.BankApplications.AsynchronousExchange Then
			Items.SynchronizeWithBank.Visible = True;
		EndIf;
	EndIf;
	
	GenerateTreesED();
	DisplayTableDocument();
	
EndProcedure

&AtServer
Procedure GenerateTreesED()
	
	TreeSubordinateED.GetItems().Clear();
	OutputSubordinateDocuments(ObjectRef, TreeSubordinateED);
	
EndProcedure

&AtServer
Function GetSelectionByDocumentAttributes(ObjectReference)
	
	ObjectMetadata = ObjectReference.Metadata();
	
	If TypeOf(ObjectReference) = Type("CatalogRef.EDUsageAgreements") Then
		QueryText = 
		"SELECT ALLOWED
		|	Ref,
		|	False AS Posted,
		|	DeletionMark,
		|	Presentation
		|FROM
		|	Catalog." + ObjectMetadata.Name + "
		|WHERE
		|	Refs = &Refs
		|";
	Else
		QueryText = 
		"SELECT ALLOWED
		|	Ref,
		|	Posted,
		|	DeletionMark,
		|	Presentation
		|FROM
		|	Document." + ObjectMetadata.Name + "
		|WHERE
		|	Refs = &Refs
		|";
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", ObjectReference);
	Return Query.Execute().Select();
	
EndFunction

&AtServer
Function GetEDListByOwner(OwnerObject)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS AttachedFiles
	|WHERE
	|	AttachedFiles.FileOwner = &OwnerObject";
	Query.SetParameter("OwnerObject", OwnerObject);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Procedure OutputSubordinateDocuments(CurrentDocument, ParentalTree)
	
	TreeRows = ParentalTree.GetItems();
	Table      = GetEDListByOwner(CurrentDocument);
	If Table = Undefined Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AttachedFiles.Ref,
	|	AttachedFiles.EDStatus,
	|	AttachedFiles.EDVersionNumber,
	|	AttachedFiles.EDStatusChangeDate,
	|	AttachedFiles.EDDirection,
	|	AttachedFiles.Presentation,
	|	AttachedFiles.DeletionMark,
	|	CASE
	|		WHEN SlaveBoundFiles.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ExistenceOfSubordinateDocuments,
	|	AttachedFiles.FileOwner.Date AS OwnerDate,
	|	AttachedFiles.FileOwner.Number AS OwnerNumber,
	|	AttachedFiles.EDKind
	|FROM
	|	Catalog.EDAttachedFiles AS AttachedFiles
	|		LEFT JOIN Catalog.EDAttachedFiles AS SlaveBoundFiles
	|		ON (SlaveBoundFiles.ElectronicDocumentOwner = AttachedFiles.Ref)
	|WHERE
	|	(AttachedFiles.FileOwner = &OwnerObject
	|			OR AttachedFiles.ElectronicDocumentOwner = &OwnerObject)
	|	AND Not AttachedFiles.EDKind = VALUE(Enum.EDKinds.AddData)
	|
	|ORDER BY
	|	AttachedFiles.CreationDate";
	Query.SetParameter("OwnerObject", CurrentDocument);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ObjectTree = FormAttributeToValue("TreeSubordinateED");
		If ObjectTree.Rows.Find(Selection.Ref, , True) = Undefined Then
			NewRow = TreeRows.Add();
			FillPropertyValues(NewRow, Selection,
				"Ref, EDStatus, EDStatusChangeDate, EDDirection, Presentation, DeletionMark");
			If ValueIsFilled(Selection.OwnerDate) AND ValueIsFilled(Selection.OwnerNumber) Then
				ParametersStructure = New Structure;
				ParametersStructure.Insert("OwnerNumber", Selection.OwnerNumber);
				ParametersStructure.Insert("OwnerDate",  Selection.OwnerDate);
				ParametersStructure.Insert("EDVersion",       Selection.EDVersionNumber);
				NewRow.Presentation = ElectronicDocumentsService.DetermineEDPresentation(Selection.EDKind, ParametersStructure);
			EndIf;
			If Selection.ExistenceOfSubordinateDocuments Then
				OutputSubordinateDocuments(Selection.Ref, NewRow);
			EndIf;
			
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure DisplayTableDocument()
	
	ReportTable.Clear();
	
	Template = DataProcessors.ElectronicDocuments.GetTemplate("ED_List");
	
	PutCurrentDocument(Template);
	DisplaySubordinatedTreeNodes(TreeSubordinateED.GetItems(), Template, 1)
	
EndProcedure

&AtServer
Procedure DisplayDocumentAndPicture(TreeRow, Template, IsCurrentDocument = False, IsSubordinated = Undefined)
	
	If IsCurrentDocument Then
		If TreeRow.Posted Then
			If IsSubordinated = Undefined  Then
				If TreeSubordinateED.GetItems().Count() AND ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorTopBottom");
				ElsIf TreeSubordinateED.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorBottom");
				ElsIf ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorTop");
				Else
					AreaPicture = Template.GetArea("DocumentPostedConnectorTop");
				EndIf;
			ElsIf IsSubordinated = True Then
				If TreeRow.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorLeftBottom");
				Else
					AreaPicture = Template.GetArea("DocumentHeld");
				EndIf;
			Else
				If TreeRow.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorLeftTop");
				Else
					AreaPicture = Template.GetArea("DocumentHeld");
				EndIf;
			EndIf;
		ElsIf TreeRow.DeletionMark Then
			If IsSubordinated = Undefined Then
				If TreeSubordinateED.GetItems().Count() AND ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorTopBottom");
				ElsIf TreeSubordinateED.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorBottom");
				ElsIf ParentalEDTree.GetItems().Count() Then
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
			If TreeRow.Ref = ObjectRef Then
				If TreeSubordinateED.GetItems().Count() AND ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentWrittenConnectorTopBottom");
				ElsIf TreeSubordinateED.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentWrittenConnectorDown");
				ElsIf ParentalEDTree.GetItems().Count() Then
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
		ReportTable.Put(AreaPicture);
	Else
		If TreeRow.DeletionMark Then
			If IsSubordinated = Undefined Then
				If TreeSubordinateED.GetItems().Count() AND ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorTopBottom");
				ElsIf TreeSubordinateED.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentMarkedForDeletionConnectorBottom");
				ElsIf ParentalEDTree.GetItems().Count() Then
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
			
		ElsIf TreeRow.EDDirection = Enums.EDDirections.Incoming
			AND (SignatureRequired AND TreeRow.EDStatus = Enums.EDStatuses.ConfirmationDelivered
			OR Not SignatureRequired AND (TreeRow.EDStatus = Enums.EDStatuses.Approved
			OR TreeRow.EDStatus = Enums.EDStatuses.AdviseSent))
			OR TreeRow.EDDirection = Enums.EDDirections.Outgoing
			AND (SignatureRequired AND (TreeRow.EDStatus = Enums.EDStatuses.ConfirmationReceived
			OR TreeRow.EDStatus = Enums.EDStatuses.Delivered)
			OR Not SignatureRequired AND TreeRow.EDStatus = Enums.EDStatuses.Delivered)
			OR TreeRow.EDDirection = Enums.EDDirections.Intercompany
			AND SignatureRequired AND TreeRow.EDStatus = Enums.EDStatuses.FullyDigitallySigned Then
			If IsSubordinated = Undefined Then
				If TreeSubordinateED.GetItems().Count() AND ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorTopBottom");
				ElsIf TreeSubordinateED.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorBottom");
				ElsIf ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorTop");
				Else
					AreaPicture = Template.GetArea("DocumentPostedConnectorTop");
				EndIf;
			ElsIf IsSubordinated = True Then
				If TreeRow.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorLeftBottom");
				Else
					AreaPicture = Template.GetArea("DocumentHeld");
				EndIf;
			Else
				If TreeRow.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentPostedConnectorLeftTop");
				Else
					AreaPicture = Template.GetArea("DocumentHeld");
				EndIf;
			EndIf;
		Else
			If TreeRow.Ref = ObjectRef Then
				If TreeSubordinateED.GetItems().Count() AND ParentalEDTree.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentWrittenConnectorTopBottom");
				ElsIf TreeSubordinateED.GetItems().Count() Then
					AreaPicture = Template.GetArea("DocumentWrittenConnectorDown");
				ElsIf ParentalEDTree.GetItems().Count() Then
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
		ReportTable.Join(AreaPicture);
	EndIf;
	
	AreaDocument = Template.GetArea(?(IsCurrentDocument,"CurrentDocument", "Document"));
	If IsCurrentDocument Then
		AreaDocument.Parameters.DocumentPresentation = GetDocumentPresentationToPrint(TreeRow);
	Else
		AreaDocument.Parameters.DocumentPresentation = GetEDPresentation(TreeRow);
	EndIf;
	AreaDocument.Parameters.Document = TreeRow.Ref;
	ReportTable.Join(AreaDocument);
	
EndProcedure

&AtServer
Function NeedToDisplayVerticalConnector(LevelUp, TreeRow, LookAmongSubordinates = True)
	
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
			ParentSubordinateNodes = TreeSubordinateED.GetItems();
		Else
			ParentSubordinateNodes = ParentalEDTree.GetItems();
		EndIf;
	Else
		ParentSubordinateNodes =  ParentToFind.GetItems();
	EndIf;
	
	Return ParentSubordinateNodes.IndexOf(RowToFind) < (ParentSubordinateNodes.Count()-1);
	
EndFunction

// Displays in the tabular document the row with the document for which the subordination structure is formed
//
// Parameters
// Template - TemplateTableDocument - template on the basis of which the tabular document is formed.
&AtServer
Procedure PutCurrentDocument(Template)
	
	Selection = GetSelectionByDocumentAttributes(ObjectRef);
	If Selection.Next() Then
		DisplayDocumentAndPicture(Selection, Template, True);
	EndIf;
	
EndProcedure

// It forms the document presentation for output to tabular document
//
// Parameters
// Selection  - QueryResultSelection or FormDataTreeItem - Dataset
//              on the basis of which presentation is formed
//
// Returns:
// String   - generated presentation.
//
&AtServer
Function GetDocumentPresentationToPrint(Selection)
	
	DocumentPresentation = Selection.Presentation;
	
	Return DocumentPresentation;
	
EndFunction

&AtServer
Function GetEDPresentation(Selection)
	
	DocumentPresentation = Selection.Presentation;
	DocumentPresentation = DocumentPresentation + " <" +  Selection.EDStatus + ", "
		+ Format(Selection.EDStatusChangeDate, "DLF=") + ">";
	
	Return DocumentPresentation;
	
EndFunction

// It displays the tree rows of subordinate documents
//
// Parameters
// TreeRows - FormDataTreeItemCollection - tree
//            rows that are output to the tabular document
// Template - TemplateTableDocument - template on
//            the basis of which the data is output to the tabular document
// RecursionLevel  - Number - recursion procedure level
//
&AtServer
Procedure DisplaySubordinatedTreeNodes(TreeRows, Template, RecursionLevel)
	
	For Each TreeRow IN TreeRows Do
		
		IsCurrentObject  = (TreeRow.Ref = ObjectRef);
		IsInitialObject = (TreeRow.Ref = InitialObject);
		SubordinatedTreeNodes = TreeRow.GetItems();
		
		For ind = 1 To RecursionLevel Do
			If RecursionLevel > ind Then
				
				If NeedToDisplayVerticalConnector(RecursionLevel - ind + 1,TreeRow) Then
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
			
			Area.Parameters.Document = ?(IsInitialObject,Undefined,TreeRow.Ref);
			
			If ind = 1 Then
				ReportTable.Put(Area);
			Else
				ReportTable.Join(Area);
			EndIf;
			
		EndDo;
		
		DisplayDocumentAndPicture(TreeRow,Template,False,True);
		
		// Subordinate tree items output
		DisplaySubordinatedTreeNodes(SubordinatedTreeNodes,Template,RecursionLevel + 1);
		
	EndDo; 
	
EndProcedure

&AtClient
Procedure DisplayEDDependencies()
	
	UpdateEDDependenciesTree();
	ReportTable.Show();
	
EndProcedure

&AtServerNoContext
Function EDFSettingAttributes(Val EDFSetup)
	
	Return CommonUse.ObjectAttributesValues(EDFSetup, "Company, Counterparty");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure Refresh(Command)
	
	DisplayEDDependencies();
	ReportTable.Show();
	
EndProcedure

&AtClient
Procedure EventLogMonitor(Command)
	
	FormParameters = New Structure;
	
	Filter = New Structure;
	Filter.Insert("EDOwner", ObjectRef);
	
	FormParameters.Insert("Filter", Filter);
	FormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpenForm("InformationRegister.EDEventsLog.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SynchronizeWithBank(Command)
	
	EDFSettingAttributes = EDFSettingAttributes(EDFSetup);
	ElectronicDocumentsClient.SynchronizeWithBank(
		EDFSettingAttributes.Company, EDFSettingAttributes.Counterparty);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure ReportTableDetailsProcessing(Item, Details, StandardProcessing)
	
	DetailsObject = Item.CurrentArea.Details;
	If TypeOf(DetailsObject) = Type("CatalogRef.EDAttachedFiles") Then
		StandardProcessing = False;
		ElectronicDocumentsServiceClient.OpenEDForViewing(DetailsObject);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("FilterObject", ObjectRef);
	Items.SynchronizeWithBank.Visible = False;
	InitialObject = ObjectRef;
	If ValueIsFilled(ObjectRef) Then
		UpdateEDDependenciesTree();
	EndIf;
	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ReportTable.Show();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		UpdateEDDependenciesTree();
	EndIf;
	
EndProcedure

















