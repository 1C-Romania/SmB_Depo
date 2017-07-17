
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	RelativeSize = Parameters.RelativeSize;
	MinimalEffect = Parameters.MinimalEffect;
	Items.MinimalEffect.Visible = Parameters.RebuildingMode;
	Title = ?(Parameters.RebuildingMode,
	              NStr("en='Rebuild parameters';ru='Параметры перестроения'"),
	              NStr("en='Parameter of optimal aggregate calculation';ru='Параметр расчета оптимальных агрегатов'"));
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure("RelativeSize, MinimalEffect");
	FillPropertyValues(ChoiceResult, ThisObject);
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion
