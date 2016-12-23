
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ChangeInTransaction",    ChangeInTransaction);
	Parameters.Property("ProcessRecursively", ProcessRecursively);
	Parameters.Property("PortionSetting",        PortionSetting);
	Parameters.Property("ObjectsPercentageInPortion", ObjectsPercentageInPortion);
	Parameters.Property("ObjectsCountInPortion",   ObjectsCountInPortion);
	Parameters.Property("AbortOnError",     AbortOnError);
	
	ThereIsDataAdministrationRight = AccessRight("DataAdministration", Metadata);
	WindowOptionsKey = ?(ThereIsDataAdministrationRight, "ThereIsDataAdministrationRight", "NoDataAdministrationRights");
	If Not Parameters.ContextCall AND ThereIsDataAdministrationRight Then
		Parameters.Property("ShowServiceAttributes", ShowServiceAttributes);
		Items.GroupShowServiceAttributes.Visible = True;
	Else
		Items.GroupShowServiceAttributes.Visible = False;
	EndIf;
	
	Items.GroupProcessRecurcively.Visible = Parameters.ContextCall AND Parameters.IncludeHierarchy;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormItems();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ChangeInTransactionOnChange(Item)
	
	SetFormItems();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure;
	ChoiceResult.Insert("ChangeInTransaction",    ChangeInTransaction);
	ChoiceResult.Insert("ProcessRecursively", ProcessRecursively);
	ChoiceResult.Insert("BatchSetting",        PortionSetting);
	ChoiceResult.Insert("ObjectPercentageInBatch", ObjectsPercentageInPortion);
	ChoiceResult.Insert("ObjectNumberInBatch",   ObjectsCountInPortion);
	ChoiceResult.Insert("AbortIfError",     ChangeInTransaction Or AbortOnError);
	ChoiceResult.Insert("ShowServiceAttributes", ShowServiceAttributes);
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetFormItems()
	
	If ChangeInTransaction Then
		Items.PanelSplitOnError.Enabled = False;
	Else
		Items.PanelSplitOnError.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion














