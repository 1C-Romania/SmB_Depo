#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetDataDesign();

	CorrelationObjectName = Parameters.CorrelationObjectName;
	If Parameters.Property("InformationByColumns") Then
		ListColumns.Load(Parameters.InformationByColumns.Unload());
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	ColumnPosition = 0;
	For Each TableRow IN ListColumns Do
		If TableRow.Visible Then
			ColumnPosition = ColumnPosition + 1;
			TableRow.Position = ColumnPosition;
		Else
			TableRow.Position = -1;
		EndIf;
	EndDo;
	Close(ListColumns);
EndProcedure

&AtClient
Procedure ResetSettings(Command)
	Notification = New NotifyDescription("ResetSettingsEnd", ThisObject, CorrelationObjectName);
	ShowQueryBox(Notification, NStr("en='Set columns settings to their original state?';ru='Установить настройки колонок в первоначальное состояние?'"), QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure CheckAll(Command)
	For Each TableRow IN ListColumns Do 
		TableRow.Visible = True;
	EndDo;
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	For Each TableRow IN ListColumns Do
		If Not TableRow.ObligatoryToComplete Then
			TableRow.Visible = False;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region HandlersColumnsList

&AtClient
Procedure ColumnsListOnActivateRow(Item)
	If Item.CurrentData <> Undefined Then 
		ColumnDetails = Item.CurrentData.Note;
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetDataDesign()

	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListName");
	AppearanceField.Use = True;
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ListColumns.MandatoryToFill"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal; 
	FilterItem.RightValue =True;
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListVisible");
	AppearanceField.Use = True;
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ListColumns.MandatoryToFill"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal; 
	FilterItem.RightValue =True;
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListSynonym");
	AppearanceField.Use = True;
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ListColumns.Synonym");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("en='Standard name';ru='Стандартное наименование'"));
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.UnavailableCellTextColor);
	
EndProcedure

&AtServerNoContext
Procedure ResetSettingsOnServer(CorrelationObjectName)
	CommonUse.CommonSettingsStorageSave("DataLoadFromFile", CorrelationObjectName, Undefined,, UserName());
EndProcedure

&AtClient
Procedure ResetSettingsEnd(QuestionResult, CorrelationObjectName) Export
	If QuestionResult = DialogReturnCode.Yes Then
		ResetSettingsOnServer(CorrelationObjectName);
		ListColumns.Clear();
		Close(ListColumns);
	EndIf;
EndProcedure

#EndRegion














