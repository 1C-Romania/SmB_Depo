
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CommonUseClientServer.SetDynamicListParameter(
		List,
		"PresentationGroupingOfCommonProperties",
		NStr("en = 'Common (for several sets)'"),
		True);
	
	// Properties grouping by sets.
	DataGrouping = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGrouping.UserSettingID = "GroupPropertiesBySuite";
	DataGrouping.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGrouping.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("PropertySetGrouping");
	DataGroupItem.Use = True;
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
