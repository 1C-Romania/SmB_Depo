
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OptionsArray") Or TypeOf(Parameters.OptionsArray) <> Type("Array") Then
		ErrorText = NStr("en = 'Report variants are not specified.'");
		Return;
	EndIf;
	
	CustomizableOptions.LoadValues(Parameters.OptionsArray);
	Filter();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IsBlankString(ErrorText) Then
		Cancel = True;
		ShowMessageBox(, ErrorText);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ResetCommand(Command)
	SelectedOptionsQuantity = CustomizableOptions.Count();
	If SelectedOptionsQuantity = 0 Then
		ShowMessageBox(, NStr("en = 'Report variants are not specified.'"));
		Return;
	EndIf;
	
	VariantCount = ResetPlacementSettingsHost(CustomizableOptions);
	If VariantCount = 1 AND SelectedOptionsQuantity = 1 Then
		OptionRef = CustomizableOptions[0].Value;
		NotificationTitle = NStr("en = 'The report variant placement settings have been reset'");
		NotificationRef    = GetURL(OptionRef);
		NotificationText     = String(OptionRef);
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
	Else
		NotificationText = NStr("en = 'Settings for
		|report options placement are reset (%1 pcs.).'");
		NotificationText = StrReplace(NotificationText, "%1", Format(VariantCount, "NZ=0; NG=0"));
		ShowUserNotification(, , NotificationText);
	EndIf;
	ReportsVariantsClient.OpenFormsRefresh();
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServerNoContext
Function ResetPlacementSettingsHost(Val CustomizableOptions)
	VariantCount = 0;
	BeginTransaction();
	For Each ItemOfList IN CustomizableOptions Do
		VariantObject = ItemOfList.Value.GetObject();
		If ReportsVariants.ResetReport(VariantObject) Then
			VariantObject.Write();
			VariantCount = VariantCount + 1;
		EndIf;
	EndDo;
	CommitTransaction();
	Return VariantCount;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure Filter()
	
	QuantityBeforeFiltration = CustomizableOptions.Count();
	
	Query = New Query;
	Query.SetParameter("OptionsArray", CustomizableOptions.UnloadValues());
	Query.SetParameter("ReportType", Enums.ReportsTypes.Internal);
	Query.Text =
	"SELECT DISTINCT
	|	ReportsVariantsPlacement.Ref
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariantsPlacement
	|WHERE
	|	ReportsVariantsPlacement.Ref IN(&OptionsArray)
	|	AND ReportsVariantsPlacement.User = FALSE
	|	AND ReportsVariantsPlacement.ReportType = &ReportType
	|	AND ReportsVariantsPlacement.DeletionMark = FALSE";
	
	OptionsArray = Query.Execute().Unload().UnloadColumn("Ref");
	CustomizableOptions.LoadValues(OptionsArray);
	
	QuantityAfterFiltering = CustomizableOptions.Count();
	If QuantityBeforeFiltration <> QuantityAfterFiltering Then
		If QuantityAfterFiltering = 0 Then
			ErrorText = NStr("en = 'Not necessary to reset settings of selected report options for one or
			|multiple reasons: - Custom report options are selected.
			|- Reports options for deletion are selected.
			|- Additional or external report variants have been selected.'");
			Return;
		EndIf;
	EndIf;
	
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
