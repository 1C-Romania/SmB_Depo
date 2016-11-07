
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	Items.Section.ChoiceList.Add("<Not selected>", "<Not selected>");
	Items.Report.ChoiceList.Add("<Not selected>", "<Not selected>");
	
	For Each Subsystem IN Metadata.Subsystems Do
		
		If (NOT Subsystem.IncludeInCommandInterface) OR (Subsystem = Metadata.Subsystems.SetupAndAdministration) Then
			Continue;
		EndIf;
		
		Items.Section.ChoiceList.Add(Subsystem.Synonym, Subsystem.Synonym);
		
		For Each SubsystemItem IN Subsystem.Content Do
			If Metadata.Reports.Contains(SubsystemItem) Then
				NewRow 				= ReportsTable.Add();
				NewRow.Section 			= Subsystem.Synonym;
				NewRow.ReportSynonym 	= SubsystemItem.Synonym;
				NewRow.ReportName 		= SubsystemItem.Name;
			EndIf; 	
		EndDo; 
		
		For Each ChildSubsystem IN Subsystem.Subsystems Do
			For Each ChildSubsystemItem IN ChildSubsystem.Content Do
		 		If Metadata.Reports.Contains(ChildSubsystemItem) Then
					NewRow 				= ReportsTable.Add();
					NewRow.Section 			= Subsystem.Synonym;
					NewRow.ReportSynonym 	= ChildSubsystemItem.Synonym;
					NewRow.ReportName 		= ChildSubsystemItem.Name;
				EndIf; 	
			EndDo;	
		EndDo; 
		
	EndDo;
	
	If Metadata.Subsystems.InventoryAndPurchasing.IncludeInCommandInterface Then
		
		NewRow 				= ReportsTable.Add();
		NewRow.Section 			= Metadata.Subsystems.InventoryAndPurchasing.Synonym;
		NewRow.ReportSynonym 	= Metadata.DataProcessors.DemandPlanning.Synonym;
		NewRow.ReportName 		= Metadata.DataProcessors.DemandPlanning.Name;	
	
	EndIf;
	
	// FO check
	
	If Not Constants.FunctionalOptionAccountingCashMethodIncomeAndExpenses.Get() Then
		RowArray = ReportsTable.FindRows(New Structure("ReportName", "IncomeAndExpensesByCashMethod"));
		For Each FoundString IN RowArray Do
			ReportsTable.Delete(FoundString);
		EndDo;
	EndIf;
			
	If Not Constants.FunctionalOptionInventoryReservation.Get() Then
		RowArray = ReportsTable.FindRows(New Structure("ReportName", "OrdersPlacement"));
		For Each FoundString IN RowArray Do
			ReportsTable.Delete(FoundString);
		EndDo;
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingFixedAssets.Get() Then
		RowArray = ReportsTable.FindRows(New Structure("ReportName", "FixedAssets"));
		For Each FoundString IN RowArray Do
			ReportsTable.Delete(FoundString);
		EndDo;
		RowArray = ReportsTable.FindRows(New Structure("ReportName", "FixedAssetsOutput"));
		For Each FoundString IN RowArray Do
			ReportsTable.Delete(FoundString);
		EndDo;
	EndIf;
	
	If (NOT Constants.FunctionalOptionTransferRawMaterialsForProcessing.Get())
		AND (NOT Constants.FunctionalOptionTransferInventoryOnSafeCustody.Get())
		AND (NOT Constants.FunctionalOptionTransferGoodsOnCommission.Get()) Then
		RowArray = ReportsTable.FindRows(New Structure("ReportName", "InventoryTransferred"));
		For Each FoundString IN RowArray Do
			ReportsTable.Delete(FoundString);
		EndDo;
	EndIf;
	
	If (NOT Constants.FunctionalOptionTransferInventoryOnSafeCustody.Get())
		AND (NOT Constants.FunctionalOptionReceiveGoodsOnCommission.Get())
		AND (NOT Constants.FunctionalOptionTolling.Get()) Then
		RowArray = ReportsTable.FindRows(New Structure("ReportName", "InventoryReceived"));
		For Each FoundString IN RowArray Do
			ReportsTable.Delete(FoundString);
		EndDo;
	EndIf;
	
	ReportsTable.Sort("Section, ReportSynonym");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.Report.ChoiceList.Clear();
	
	If ValueIsFilled(Section) Then
		Filter = New Structure("Section", Section);
		RowArray = ReportsTable.FindRows(Filter);
		For Each FoundString IN RowArray Do
			Items.Report.ChoiceList.Add(FoundString.ReportSynonym, FoundString.ReportSynonym);
		EndDo;		
	Else		
		Section 	= "<Not selected>";
		
		For Each FoundString IN ReportsTable Do
			Items.Report.ChoiceList.Add(FoundString.ReportSynonym, FoundString.ReportSynonym);
		EndDo;	
	EndIf; 
	
	If Not ValueIsFilled(Report) Then
		Report = "<Not selected>";
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - SelectionDataProcessor event handler of the Section entry field.
//
Procedure SectionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Section = ValueSelected;
	
	Items.Report.ChoiceList.Clear();
	
	If Section = "<Not selected>" Then
		
		For Each FoundString IN ReportsTable Do
			Items.Report.ChoiceList.Add(FoundString.ReportSynonym, FoundString.ReportSynonym);
		EndDo;	
		
	Else
		
		Filter = New Structure("Section", Section);
		RowArray = ReportsTable.FindRows(Filter);
		For Each FoundString IN RowArray Do
			Items.Report.ChoiceList.Add(FoundString.ReportSynonym, FoundString.ReportSynonym);
		EndDo;	
	
	EndIf; 
	
	Report = "<Not selected>";
	
EndProcedure

&AtClient
// Procedure - command handler Show.
//
Procedure Show(Command)
	
	If Report 	= "<Not selected>" Then
	
		Message = New UserMessage();
		Message.Text = NStr("en='Report is not selected!';ru='Не выбран отчет!'");	
		Message.Field = "Report";
		Message.Message();	
	
	Else
	
		Filter = New Structure("ReportSynonym", Report);
		RowArray = ReportsTable.FindRows(Filter);
		For Each FoundString IN RowArray Do
			If FoundString.ReportName = "DemandPlanning" Then
				OpenForm("DataProcessor." + FoundString.ReportName + ".Form");
			Else
				OpenForm("Report." + FoundString.ReportName + ".Form");
			EndIf; 
			
			Break;
		EndDo;		
	
	EndIf; 
	
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
