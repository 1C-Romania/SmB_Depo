
Procedure PeriodPresentationSelectPeriod(Form, FilterListName="List", FieldFilterName="Date", StructureItemNames = Undefined) Export
	
	Parameters = New Structure("Form, FilterListName, FieldFilterName", Form, FilterListName, FieldFilterName);
	If Not (StructureItemNames = Undefined) Then
		Parameters.Insert("StructureItemNames", StructureItemNames);
	EndIf;
	
	Notify = New NotifyDescription("PeriodPresentationClickCompleted", ThisObject, Parameters);
	
	Dialog = New StandardPeriodEditDialog;
	If StructureItemNames = Undefined Then
		Dialog.Period = Form.FilterPeriod;
	Else
		Dialog.Period = Form[StructureItemNames.FilterPeriod];
	EndIf;
	Dialog.Show(Notify);
	
EndProcedure

Procedure PeriodPresentationClickCompleted(NewPeriod, Parameters) Export
	
	If NewPeriod = Undefined Then
		Return;
	EndIf;
	Form			= Parameters.Form;
	FilterListName	= Parameters.FilterListName;
	FieldFilterName	= Parameters.FieldFilterName;
	
	If Parameters.Property("StructureItemNames") Then
	
		If TypeOf(NewPeriod)=Type("StandardPeriod") Then
			Form[Parameters.StructureItemNames.FilterPeriod] = NewPeriod;
		ElsIf TypeOf(NewPeriod)=Type("Date") Then
			Form[Parameters.StructureItemNames.FilterPeriod].EndDate = NewPeriod;
		EndIf;
		
		Form[Parameters.StructureItemNames.PeriodPresentation] = WorkWithFiltersClientServer.RefreshPeriodPresentation(Form[Parameters.StructureItemNames.FilterPeriod]);
		WorkWithFiltersClientServer.SetFilterByPeriod(
			Form[FilterListName].SettingsComposer.Settings.Filter, 
			Form[Parameters.StructureItemNames.FilterPeriod].StartDate, 
			Form[Parameters.StructureItemNames.FilterPeriod].EndDate, FieldFilterName);
			
		If Parameters.StructureItemNames.Property("NotificationEvent") Then
			Notify(Parameters.StructureItemNames.NotificationEvent);
		EndIf;
			
	Else
		
		If TypeOf(NewPeriod)=Type("StandardPeriod") Then
			Form.FilterPeriod = NewPeriod;
		ElsIf TypeOf(NewPeriod)=Type("Date") Then
			Form.FilterPeriod.EndDate = NewPeriod;
		EndIf;
		
		Form.PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(Form.FilterPeriod);
		WorkWithFiltersClientServer.SetFilterByPeriod(Form[FilterListName].SettingsComposer.Settings.Filter, Form.FilterPeriod.StartDate, Form.FilterPeriod.EndDate, FieldFilterName);
		
	EndIf;
	
	#If WebClient Then
		Form.RefreshDataRepresentation();
	#EndIf 

EndProcedure

Procedure CollapseExpandFiltesPanel(Form, Visible, StructureItemNames = Undefined) Export
	
	InterfaceTaxi = True;
	#If WebClient Then
	InterfaceTaxi = (ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi);
	#EndIf

	If StructureItemNames = Undefined Then
		Form.Items.FilterSettingsAndAddInfo.Visible	= Visible;
		Form.Items.DecorationExpandFilters.Visible	= Not Visible;
		Form.Items.RightPanel.Width					= ?(Visible, ?(InterfaceTaxi, 25, 24), 0);
	Else
		Form.Items[StructureItemNames.FilterSettingsAndAddInfo].Visible	= Visible;
		Form.Items[StructureItemNames.DecorationExpandFilters].Visible	= Not Visible;
		Form.Items[StructureItemNames.RightPanel].Width					= ?(Visible, ?(InterfaceTaxi, 25, 24), 0);
	EndIf;
	
EndProcedure