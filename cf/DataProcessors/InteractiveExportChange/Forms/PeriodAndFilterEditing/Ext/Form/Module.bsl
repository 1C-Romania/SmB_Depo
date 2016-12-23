
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	
	Title = Parameters.Title;
	
	If Parameters.Property("AddressLinkerSettings", AddressLinkerSettings) Then
		// Storage has higher priority
		Data = GetFromTempStorage(AddressLinkerSettings);
 		SchemaURLComposition = PutToTempStorage(Data.CompositionSchema, UUID);;
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURLComposition));
		SettingsComposer.LoadSettings(Data.Settings);
	Else
		SchemaURLComposition = "";
		SettingsComposer = Parameters.SettingsComposer;
	EndIf;
	
	Parameters.Property("PeriodOfData", PeriodOfData);
	
	If Parameters.PeriodSelection Then
		ExportingForPeriod = True;
	Else
		ExportingForPeriod = False;
		// Disable the period choice totaly.
		Items.PeriodOfData.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetEnabledPeriodFilter();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers
//

&AtClient
Procedure PeriodDataClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

&AtClient
Procedure CommandOK(Command)
	NotifyChoice(ChoiceResult());
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
//

&AtClient
Procedure SetEnabledPeriodFilter()
	Items.PeriodOfData.Enabled = ExportingForPeriod;
EndProcedure

&AtServer
Function ChoiceResult()
	Result = New Structure;
	Result.Insert("ActionSelect",      Parameters.ActionSelect);
	Result.Insert("SettingsComposer", SettingsComposer);
	Result.Insert("PeriodOfData",        ?(ExportingForPeriod, PeriodOfData, New StandardPeriod));
	
	Result.Insert("AddressLinkerSettings");
	If Not IsBlankString(AddressLinkerSettings) Then
		Data = New Structure;
		Data.Insert("Settings", SettingsComposer.Settings);
		
		CompositionSchema = ?(IsBlankString(SchemaURLComposition), Undefined, GetFromTempStorage(SchemaURLComposition));
		Data.Insert("CompositionSchema", CompositionSchema);
		
		Result.AddressLinkerSettings = PutToTempStorage(Data, Parameters.AddressOfFormStore);
	EndIf;
		
	Return Result;
EndFunction

#EndRegion














