
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