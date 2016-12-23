
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableEditingAbility(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure RefreshDataRegister(Command)
	
	HasChanges = False;
	
	RegisterDataUpdateOnServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en='Updated successfully.';ru='Обновление выполнено успешно.'");
	Else
		Text = NStr("en='No need to update.';ru='Обновление не требуется.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	IssueDataGroup(0, NStr("en='Standard access value';ru='Стандартные значения доступа'"));
	IssueDataGroup(1, NStr("en='Ordinary/external users';ru='Обычные/внешние пользователи'"));
	IssueDataGroup(2, NStr("en='Ordinary/external user groups';ru='Обычные/внешние группы пользователей'"));
	IssueDataGroup(3, NStr("en='Performers groups';ru='Группы исполнителей'"));
	IssueDataGroup(4, NStr("en='Authorization objects';ru='Объекты авторизации'"));
	
EndProcedure

&AtServer
Procedure IssueDataGroup(DataGroup, Text)
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DataGroupList.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.DataGroup");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = DataGroup;
	
	Item.Appearance.SetParameterValue("Text", Text);
	
EndProcedure

&AtServer
Procedure RegisterDataUpdateOnServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.AccessValuesGroups.RefreshDataRegister(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion














