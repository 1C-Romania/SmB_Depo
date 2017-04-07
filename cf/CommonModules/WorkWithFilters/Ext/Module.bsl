
#Region FilterLabels

Procedure AttachFilterLabel(Form, FilterFieldName, GroupParentName, Label, LabelDescription, ListName = "", QueryParameterName="", TPNameLabelData = "LabelData") Export
	
	CreateLabelItems(Form, FilterFieldName, GroupParentName, Label, LabelDescription, ListName, QueryParameterName, TPNameLabelData);
	RefreshLabelItems(Form,, TPNameLabelData);
	
EndProcedure

Procedure CreateLabelItems(Form, FilterFieldName, GroupParentName, Label, LabelDescription, ListName = "", QueryParameterName="", TPNameLabelData = "LabelData") Export
	
	Items = Form.Items;
	LabelData = Form[TPNameLabelData];
	
	If LabelData.Count() > 0 Then
		If ListName <> "" And LabelData[0].Property("ListName") Then
			StructureSearchFilterValues = New Structure("Label, ListName, FilterFieldName", Label, ListName, FilterFieldName);
		Else
			StructureSearchFilterValues = New Structure("Label, FilterFieldName", Label, FilterFieldName);
		EndIf;
		If LabelData.FindRows(StructureSearchFilterValues).Count() > 0 Then
			Return;
		EndIf;
	EndIf;
	
	If TypeOf(Label)=Type("Array") Then
		LabelList = New ValueList;
		LabelList.LoadValues(Label);
		Label = LabelList;
	EndIf; 
	
	LabelRow = LabelData.Add();
	URLFS = GetLabelNameBeginning(TPNameLabelData) + LabelRow.GetID();
	
	LabelRow.Label = Label;
	LabelRow.FilterFieldName	= FilterFieldName;
	LabelRow.GroupParentName	= GroupParentName;
	If ClientApplicationInterfaceCurrentVariant() <> ClientApplicationInterfaceVariant.Taxi Then
		LabelPresentation = FormattedStringLabelPresentation(Left(LabelDescription,16), URLFS);
	Else
		LabelPresentation = FormattedStringLabelPresentation(Left(LabelDescription,21), URLFS);
	EndIf;
	LabelRow.LabelPresentation = LabelPresentation;
	If LabelRow.Property("ListName") Then
		LabelRow.ListName = ListName;
	EndIf;
	If LabelRow.Property("QueryParameterName") Then
		LabelRow.QueryParameterName= QueryParameterName;
	EndIf;
	
EndProcedure

Procedure SetListFilter(Form, FilterList, FilterFieldName, ListName = "", UsingFilter=Undefined, TPNameLabelData = "LabelData") Export
	
	FilterArray = New Array;
	For Each Row In Form[TPNameLabelData] Do
		If Row.FilterFieldName = FilterFieldName And (ListName = "" Or (Row.Property("ListName") And ListName = Row.ListName)) Then
			If TypeOf(Row.Label)=Type("ValueList") Then
				For Each ListValue In Row.Label Do
				    FilterArray.Add(ListValue.Value);
				EndDo; 
			Else	
				FilterArray.Add(Row.Label);
			EndIf;
		EndIf;
	EndDo;
	
	If UsingFilter=Undefined Then
		UsingFilter = ValueIsFilled(FilterArray);
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(FilterList, FilterFieldName, FilterArray, UsingFilter,
		DataCompositionComparisonType.InList);
	
EndProcedure

Procedure SetListQueryParameter(Form, FilterList, FilterFieldName, QueryParameterName, TPNameLabelData = "LabelData") Export
	
	FilterArray = New Array;
	FilterValueRows = Form[TPNameLabelData].FindRows(New Structure("FilterFieldName", FilterFieldName));
	For Each FilterRow In FilterValueRows Do
		If TypeOf(FilterRow.Label)=Type("ValueList") Then
			For Each ListValue In FilterRow.Label Do
				FilterArray.Add(ListValue.Value);
			EndDo;
		Else	
			FilterArray.Add(FilterRow.Label);
		EndIf;
	EndDo;
	
	FilterList.Parameters.SetParameterValue("WithoutFilter", Not ValueIsFilled(FilterArray));
	FilterList.Parameters.SetParameterValue(QueryParameterName, FilterArray);
	
EndProcedure

Function GetLabelNameBeginning(TPNameLabelData) Export
	
	If TPNameLabelData = "LabelData" Then
		BeginningLabelName = "Label_";
	ElsIf TPNameLabelData = "LabelDataPP" Then
		BeginningLabelName = "LabelPP_";
	EndIf;
	
	Return BeginningLabelName;
	
EndFunction

Procedure RefreshLabelItems(Form, ListFormGroupsForDeletingAddedItems=Undefined, TPNameLabelData = "LabelData") Export
	
	Items = Form.Items;
	LabelData = Form[TPNameLabelData];
	
	If ListFormGroupsForDeletingAddedItems=Undefined Then
		ListFormGroupsForDeletingAddedItems = GetListNameGroupParent(LabelData);
	EndIf;
	
	DeletingItems = New Array;
	
	For Each FormGroup In ListFormGroupsForDeletingAddedItems Do
		AddLabelsForDeleting(Form.Items[FormGroup], DeletingItems);
	EndDo;
	For Each DeletingItem In DeletingItems Do
		Items.Delete(DeletingItem);
	EndDo;
	
	LabelNumber = 0;
	For Each LabelDataItem In LabelData Do
		
		GroupParent = Form.Items[LabelDataItem.GroupParentName];
		
		FieldLabel = Items.Add(GetLabelNameBeginning(TPNameLabelData) + LabelNumber, Type("FormField"), GroupParent);
		FieldLabel.Type = FormFieldType.LabelField;
		FieldLabel.DataPath = TPNameLabelData + "[" + LabelNumber + "].LabelPresentation";
		FieldLabel.TitleLocation = FormItemTitleLocation.None;
		FieldLabel.HorizontalStretch = True;
		FieldLabel.SetAction("URLProcessing", "Attachable_LabelURLProcessing");
		FieldLabel.ToolTip = LabelDataItem.Label;
		// if not Taxi
		If ClientApplicationInterfaceCurrentVariant() <> ClientApplicationInterfaceVariant.Taxi Then
			Font = New Font(FieldLabel.Font,, 10);
			FieldLabel.Font = Font;
		EndIf;
		
		LabelNumber = LabelNumber + 1;
		
	EndDo;
	
EndProcedure

Procedure CollapseExpandFiltersAtServer(Form, Visible, StructureItemNames = Undefined) Export
	
	Items = Form.Items;
	
	InterfaceTaxi = (ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi);
	If StructureItemNames = Undefined Then
		If Items.Find("DecorationExpandFilters")=Undefined Then
			Return;
		EndIf;
		
		Items.FilterSettingsAndAddInfo.Visible	= Visible;
		Items.DecorationExpandFilters.Visible	= Not Visible;
		Items.RightPanel.Width					= ?(Visible, ?(InterfaceTaxi, 25, 24), 0);
	Else
		Items[StructureItemNames.FilterSettingsAndAddInfo].Visible	= Visible;
		Items[StructureItemNames.DecorationExpandFilters].Visible	= Not Visible;
		Items[StructureItemNames.RightPanel].Width					= ?(Visible, ?(InterfaceTaxi, 25, 24), 0);
	EndIf;
	
EndProcedure

Procedure DeleteFilterLabelServer(Form, FilterList, LabelID, ListName = "", TPNameLabelData = "LabelData") Export
	
	LabelData = Form[TPNameLabelData];
	
	LabelsRow = LabelData[Number(LabelID)];
	FilterFieldName = LabelsRow.FilterFieldName;
	QueryParameterName = ?(LabelsRow.Property("QueryParameterName"), LabelsRow.QueryParameterName,"");
	
	ListFormGroupsForDeletingAddedItems = GetListNameGroupParent(LabelData);
	
	LabelData.Delete(LabelsRow);
	
	RefreshLabelItems(Form, ListFormGroupsForDeletingAddedItems, TPNameLabelData);
	If QueryParameterName="" Then
		SetListFilter(Form, FilterList, FilterFieldName, ListName);
	Else
		SetListQueryParameter(Form, FilterList, FilterFieldName, QueryParameterName);
	EndIf;
	
EndProcedure

Function GetListNameGroupParent(LabelData)
	
	ListFormGroupsForDeletingAddedItems = LabelData.Unload();
	ListFormGroupsForDeletingAddedItems.GroupBy("GroupParentName","");
	
	Return ListFormGroupsForDeletingAddedItems.UnloadColumn("GroupParentName");
	
EndFunction

Procedure SaveFilterSettings(Val Form, ListName = "", StructureItemNames = Undefined, FormFiltersOption="", SetFilterByPeriod = True, TPNameLabelData = "LabelData") Export
	
	ObjectKeyName = StrReplace(Form.FormName,".","")+FormFiltersOption;
	
	If ListName = "" Then
		LabelData = Form[TPNameLabelData].Unload();
	Else
		LabelData = Form[TPNameLabelData].Unload();
	EndIf;
	
	If StructureItemNames = Undefined Then
		CommonUse.CommonSettingsStorageSave(ObjectKeyName, ObjectKeyName+ListName+"_LabelData", LabelData);
		If SetFilterByPeriod Then
			CommonUse.CommonSettingsStorageSave(ObjectKeyName, ObjectKeyName+ListName+"_FilterByPeriod", Form.FilterPeriod);
		EndIf;
		CommonUse.CommonSettingsStorageSave(ObjectKeyName, ObjectKeyName+ListName+"_FilterPanelVisible", Form.Items.FilterSettingsAndAddInfo.Visible);
	Else
		CommonUse.CommonSettingsStorageSave(ObjectKeyName, ObjectKeyName+ListName+"_LabelData", LabelData);
		If SetFilterByPeriod Then
			CommonUse.CommonSettingsStorageSave(ObjectKeyName, ObjectKeyName+ListName+"_FilterByPeriod", Form[StructureItemNames.FilterPeriod]);
		EndIf; 
		CommonUse.CommonSettingsStorageSave(ObjectKeyName, ObjectKeyName+ListName+"_FilterPanelVisible", Form.Items[StructureItemNames.FilterSettingsAndAddInfo].Visible);
	EndIf;
	
EndProcedure

Procedure RestoreFilterSettings(Form, FilterList, ListName = "", 
	StructureItemNames = Undefined, StructureFilterFieldNames = Undefined,
	FormFilterOption="", SetFilterByPeriod = True, TPNameLabelData = "LabelData") Export
	
	ObjectKeyName = StrReplace(Form.FormName,".","")+FormFilterOption;
	//Filters by right panel fields
	SavedValue = CommonUse.CommonSettingsStorageImport(ObjectKeyName, ObjectKeyName+ListName+"_LabelData");
	IsCurrentListFilter = False;
	
	If ValueIsFilled(SavedValue) Then
		
		//Check the saved filters, remove rows that are not
		If SavedValue.Columns.Find("QueryParameterName")=Undefined Then
			ArrayAvailableCompositionSchemaFields = New Array;
			For Each FilterField In FilterList.Filter.FilterAvailableFields.Items Do
				ArrayAvailableCompositionSchemaFields.Add(Строка(FilterField.Field));
			EndDo;
			ArrayDeleteFilters = New Array;
			For Each SavedFilterField In SavedValue Do
				If StrFind(SavedFilterField.FilterFieldName,".")<>0 Then
					//For the table fields, which are presented through the point
					FieldArray = StrSplit(SavedFilterField.FilterFieldName, ".");
					If FieldArray.Count()>0 Then
						SavedFilterFieldName = FieldArray[0];
					EndIf;
				Else
					SavedFilterFieldName = SavedFilterField.FilterFieldName;
				EndIf;
				If ArrayAvailableCompositionSchemaFields.Find(SavedFilterFieldName)=Undefined Then
					ArrayDeleteFilters.Add(SavedFilterField);
				EndIf;
			EndDo;
			For Each RowDelete In ArrayDeleteFilters Do
				SavedValue.Delete(RowDelete);
			EndDo;
		EndIf; 
		
		Form[TPNameLabelData].Load(SavedValue);
		
		//Set list filter according to table LabelData data
		IsListName = False; // for forms with multiple dynamic lists
		IsQueryParameterName = False; // for forms, where the filter is established through dynamic parameter list query
		
		TableFieldRowForCollapse = "FilterFieldName";
		If SavedValue.Columns.Find("ListName")<>Undefined Then
			TableFieldRowForCollapse = TableFieldRowForCollapse + ",ListName";
			IsListName = True;
		EndIf;
		If SavedValue.Columns.Find("QueryParameterName")<>Undefined Then
			TableFieldRowForCollapse = TableFieldRowForCollapse + ",QueryParameterName";
			IsQueryParameterName = True;
		endIf;
		FilterFieldTableName = SavedValue.Copy(,TableFieldRowForCollapse);
		FilterFieldTableName.GroupBy(TableFieldRowForCollapse, "");
		For Each FilterFieldRow In FilterFieldTableName Do //cycle by filter field name
			
			//If there is no column "ListName", filter by composition
			//If there is a list of the name, it is necessary to verify that the filter field belongs to this list
			FilterFieldBelongsList = Not IsListName Or (IsListName And FilterFieldRow.ListName = ListName);
			
			If (IsQueryParameterName And FilterFieldRow.QueryParameterName<>""
				And FilterFieldBelongsList) Then
				//filter by setting a list of query parameters
				SetListQueryParameter(Form, FilterList, FilterFieldRow.FilterFieldName, FilterFieldRow.QueryParameterName, TPNameLabelData);
				IsCurrentListFilter = True;
			ElsIf FilterFieldBelongsList Then
				//filter by composition
				SetListFilter(Form, FilterList, FilterFieldRow.FilterFieldName,, True, TPNameLabelData);
				IsCurrentListFilter = True;
			EndIf;
			
		EndDo;
		
		RefreshLabelItems(Form,, TPNameLabelData);
		
	EndIf;
	
	//Filter by period
	If SetFilterByPeriod Then
		If StructureItemNames = Undefined Then
			Form.FilterPeriod = CommonUse.CommonSettingsStorageImport(ObjectKeyName, ObjectKeyName+ListName+"_FilterByPeriod");
			Form.PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(Form.FilterPeriod);
			If StructureFilterFieldNames<> Undefined And StructureFilterFieldNames.Property("FilterPeriod") Then
				FieldFilterNamePeriod = StructureFilterFieldNames.FilterPeriod;
			Else
				FieldFilterNamePeriod = "Date";
			EndIf;
			
			WorkWithFiltersClientServer.SetFilterByPeriod(FilterList.SettingsComposer.Settings.Filter, Form.FilterPeriod.StartDate, Form.FilterPeriod.EndDate, FieldFilterNamePeriod);
		Else
			Form[StructureItemNames.FilterPeriod] = CommonUse.CommonSettingsStorageImport(ObjectKeyName, ObjectKeyName+ListName+"_FilterByPeriod");
			Form[StructureItemNames.PeriodPresentation] = WorkWithFiltersClientServer.RefreshPeriodPresentation(Form[StructureItemNames.FilterPeriod]);
			WorkWithFiltersClientServer.SetFilterByPeriod(FilterList.SettingsComposer.Settings.Filter, 
				Form[StructureItemNames.FilterPeriod].StartDate, 
				Form[StructureItemNames.FilterPeriod].EndDate);
		EndIf;
	EndIf;
	
	//Visibility filter panel
	If Not IsCurrentListFilter And (Not SetFilterByPeriod Or Not ValueIsFilled(Form.FilterPeriod)) Then
		SavedValue = CommonUse.CommonSettingsStorageImport(ObjectKeyName, ObjectKeyName+ListName+"_VisibilityFilterPanel", True);
		If ValueIsFilled(SavedValue) Then
			CollapseExpandFiltersAtServer(Form, SavedValue, StructureItemNames);
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddLabelsForDeleting(ItemGroup, DeletingItems)
	
	For Each LabelRow In ItemGroup.ChildItems Do
		If LabelRow.Type=FormFieldType.InputField Then
			Continue;
		EndIf;
		DeletingItems.Add(LabelRow);
	EndDo;
	
EndProcedure

Function FormattedStringLabelPresentation(LabelDescription, URLFS)
	
	Color	= StyleColors.MinorInscriptionText;
	Font	= StyleFonts.FontRightFilterPanel;
	
	ComponentsFS = New Array;
	ComponentsFS.Add(New FormattedString(LabelDescription + " ", Font, Color));
	ComponentsFS.Add(New FormattedString(PictureLib.Clear, , , , URLFS));
	
	Return New FormattedString(ComponentsFS);
	
EndFunction

#EndRegion

