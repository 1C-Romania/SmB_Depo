﻿
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CompositionSettings = Undefined;
	
	If IsTempStorageURL(Parameters.AddressOfCompositionSettings) Then
		
		CompositionSettings = GetFromTempStorage(Parameters.AddressOfCompositionSettings);
		
	EndIf;
		
	InitializeComposerServer(CompositionSettings);
	
EndProcedure

&AtServer
Procedure InitializeComposerServer(CompositionSettings)
	
	ProductsExportScheme = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("ProductsExportScheme");
	SchemaURL = PutToTempStorage(ProductsExportScheme, UUID);
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL)); 
	
	If CompositionSettings = Undefined Then
		DataCompositionSettingsComposer.LoadSettings(ProductsExportScheme.DefaultSettings);
	Else
		DataCompositionSettingsComposer.LoadSettings(CompositionSettings);
		DataCompositionSettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
	
EndProcedure

&AtServer
Function GetCompositionSettingsServer()
	
	Return DataCompositionSettingsComposer.GetSettings();
	
EndFunction

&AtClient
Procedure FinishEdit(Command)
	
	Close(GetCompositionSettingsServer());
	
EndProcedure



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
