
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	List.Parameters.Items[0].Value = Parameters.InfobaseNode;
	List.Parameters.Items[0].Use = True;
	
	Title = NStr("en = 'Data synchronization scripts for: [IBNode]'");
	Title = StrReplace(Title, "[DataBaseNode]", String(Parameters.InfobaseNode));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_DataExchangeScripts" Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.List.RowData(SelectedRow);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Field = Items.UseImportFlag Then
		
		EnableDisableImportAtServer(CurrentData.UseImportFlag, CurrentData.Ref);
		
	ElsIf Field = Items.UseExportFlag Then
		
		EnableDisableDumpAtServer(CurrentData.UseExportFlag, CurrentData.Ref);
		
	ElsIf Field = Items.Description Then
		
		ChangeScriptOfDataExchange(Undefined);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Create(Command)
	
	FormParameters = New Structure("InfobaseNode", Parameters.InfobaseNode);
	
	OpenForm("Catalog.DataExchangeScripts.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeScriptOfDataExchange(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", CurrentData.Ref);
	
	OpenForm("Catalog.DataExchangeScripts.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EnableDisableScheduledJob(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableScheduledJobAtServer(CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EnableDisableDump(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableDumpAtServer(CurrentData.UseExportFlag, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EnableDisableImport(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableImportAtServer(CurrentData.UseImportFlag, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EnableDisableImportDump(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableImportDumpAtServer(CurrentData.UseImportFlag OR CurrentData.UseExportFlag, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure RunScript(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Message = NStr("en = 'Data is being synchronized according to script ""%1""...'");
	Message = StringFunctionsClientServer.PlaceParametersIntoString(Message, String(CurrentData.Ref));
	
	Status(Message);
	
	Cancel = False;
	
	// Start the exchange.
	DataExchangeServerCall.ExecuteDataExchangeByScenarioOfExchangeData(Cancel, CurrentData.Ref);
	
	If Cancel Then
		Message = NStr("en = 'Synchronization script is performed with errors.'");
		Picture = PictureLib.Error32;
	Else
		Message = NStr("en = 'Synchronization script has been successfully completed.'");
		Picture = Undefined;
	EndIf;
	
	Status(Message,,, Picture);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure EnableDisableScheduledJobAtServer(Ref)
	
	SettingsObject = Ref.GetObject();
	SettingsObject.UseScheduledJob = Not SettingsObject.UseScheduledJob;
	SettingsObject.Write();
	
	// update data of the list
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableDumpAtServer(Val UseExportFlag, Val DataExchangeScenario)
	
	If UseExportFlag Then
		
		Catalogs.DataExchangeScripts.DeleteDumpInDataExchangeScript(DataExchangeScenario, Parameters.InfobaseNode);
		
	Else
		
		Catalogs.DataExchangeScripts.AddDumpToDataExchangeScripts(DataExchangeScenario, Parameters.InfobaseNode);
		
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableImportAtServer(Val UseImportFlag, Val DataExchangeScenario)
	
	If UseImportFlag Then
		
		Catalogs.DataExchangeScripts.DeleteImportInDataExchangeScript(DataExchangeScenario, Parameters.InfobaseNode);
		
	Else
		
		Catalogs.DataExchangeScripts.AddImportingToDataExchangeScripts(DataExchangeScenario, Parameters.InfobaseNode);
		
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableImportDumpAtServer(Val UsageFlag, Val DataExchangeScenario)
	
	EnableDisableImportAtServer(UsageFlag, DataExchangeScenario);
	
	EnableDisableDumpAtServer(UsageFlag, DataExchangeScenario);
	
EndProcedure

#EndRegion
