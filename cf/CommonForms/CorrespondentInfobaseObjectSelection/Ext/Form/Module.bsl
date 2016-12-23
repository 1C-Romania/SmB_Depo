
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Parameters.Property("ChoiceFoldersAndItems", ChoiceFoldersAndItems);
	
	PickMode = (Parameters.CloseOnChoice = False);
	AttributeName = Parameters.AttributeName;
	
	If Parameters.ExternalConnectionParameters.ConnectionType = "ExternalConnection" Then
		
		Connection = DataExchangeReUse.InstallOuterDatabaseJoin(Parameters.ExternalConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDescription;
		ExternalConnection       = Connection.Join;
		
		If ExternalConnection = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		MetadataObjectProperties = ExternalConnection.DataExchangeExternalConnection.MetadataObjectProperties(Parameters.CorrespondentInfobaseTableFullName);
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			OR Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetTableObjects_2_0_1_6(Parameters.CorrespondentInfobaseTableFullName));
			
		Else
			
			CorrespondentInfobaseTable = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetTableObjects(Parameters.CorrespondentInfobaseTableFullName));
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.ConnectionType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		ElsIf Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			CommonUseClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			OR Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentBaseData = XDTOSerializer.ReadXDTO(WSProxy.GetInfobaseData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = CorrespondentBaseData.MetadataObjectProperties;
			CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(CorrespondentBaseData.CorrespondentInfobaseTable);
			
		Else
			
			CorrespondentBaseData = ValueFromStringInternal(WSProxy.GetInfobaseData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = ValueFromStringInternal(CorrespondentBaseData.MetadataObjectProperties);
			CorrespondentInfobaseTable = ValueFromStringInternal(CorrespondentBaseData.CorrespondentInfobaseTable);
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.ConnectionType = "TempStorage" Then
		
		CorrespondentBaseData = GetFromTempStorage(
			Parameters.ExternalConnectionParameters.TemporaryStorageAddress
		).Get().Get(Parameters.CorrespondentInfobaseTableFullName);
		
		MetadataObjectProperties = CorrespondentBaseData.MetadataObjectProperties;
		CorrespondentInfobaseTable = CommonUse.ValueFromXMLString(CorrespondentBaseData.CorrespondentInfobaseTable);
		
	EndIf;
	
	RefreshIndexesIconElements(CorrespondentInfobaseTable);
	
	Title = MetadataObjectProperties.Synonym;
	
	Items.List.Representation = ?(MetadataObjectProperties.Hierarchical = True, TableRepresentation.HierarchicalList, TableRepresentation.List);
	
	TreeItemCollection = List.GetItems();
	TreeItemCollection.Clear();
	CommonUse.FillItemCollectionOfFormDataTree(TreeItemCollection, CorrespondentInfobaseTable);
	
	// Cursor positioning in a value tree.
	If Not IsBlankString(Parameters.ChoiceInitialValue) Then
		
		RowID = 0;
		
		CommonUseClientServer.GetTreeRowIDByFieldValue("ID", RowID, TreeItemCollection, Parameters.ChoiceInitialValue, False);
		
		Items.List.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ValueChoiceProcessing();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseValue(Command)
	
	ValueChoiceProcessing();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ValueChoiceProcessing()
	CurrentData = Items.List.CurrentData;
	
	If CurrentData=Undefined Then 
		Return
	EndIf;
	
	// Calculate group flag indirectly:
	//     0 - Not marked for deletion group.
	//     1 - Marked for deletion group.
	
	IsFolder = CurrentData.PictureIndex=0 Or CurrentData.PictureIndex=1;
	If (IsFolder AND ChoiceFoldersAndItems=FoldersAndItems.Items) 
		Or (NOT IsFolder AND ChoiceFoldersAndItems=FoldersAndItems.Folders)
	Then
		Return;
	EndIf;
	
	Data = New Structure("Presentation, Identifier");
	FillPropertyValues(Data, CurrentData);
	
	Data.Insert("PickMode", PickMode);
	Data.Insert("AttributeName", AttributeName);
	
	NotifyChoice(Data);
EndProcedure

// To ensure backward compatibility.
//
&AtServer
Procedure RefreshIndexesIconElements(CorrespondentInfobaseTable)
	
	For IndexOf = -3 To -2 Do
		
		Filter = New Structure;
		Filter.Insert("PictureIndex", - IndexOf);
		
		FoundIndexes = CorrespondentInfobaseTable.Rows.FindRows(Filter, True);
		
		For Each FoundIndex IN FoundIndexes Do
			
			FoundIndex.PictureIndex = FoundIndex.PictureIndex + 1;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion














