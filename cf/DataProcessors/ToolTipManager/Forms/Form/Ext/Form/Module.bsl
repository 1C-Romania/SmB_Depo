
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Title") Then
		Title = NStr("en='ToolTip: ';ru='Подсказка: '") + Parameters.Title;
	EndIf;
	
	If Parameters.Property("ToolTipKey") Then
		ToolTipTemplate = DataProcessors.ToolTipManager.GetTemplate(Parameters.ToolTipKey).GetText();
	EndIf;
	
EndProcedure

&AtClient
Procedure ToolTipTemplateOnClick(Item, EventData, StandardProcessing)
	
	If Find(EventData.href, "unf://") <> 0 Then
		
		StandardProcessing = False;
		StringFormName = EventData.href;
		If Find(EventData.href, "v8cfgHelp") <> 0 Then
			StringFormName = StrReplace(StringFormName, "v8cfgHelp/v8config/", "");
		EndIf;
		StringFormName = StrReplace(StringFormName, "unf://", "");
		StringFormName = StrReplace(StringFormName, "/", "");
		Try
			OpenForm(StringFormName);
		Except
		EndTry;
		
	EndIf;
	
EndProcedure
