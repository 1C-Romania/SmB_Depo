////////////////////////////////////////////////////////////////////////////////
// MODAL VARIABLES MASTERS (Client)

&AtClient
Var mCurrentPageNumber;

&AtClient
Var mFirstPage;

&AtClient
Var mLastPage;

&AtClient
Var mFormRecordCompleted;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure writes the form changes.
//
&AtServer
Procedure WriteFormChanges(FinishEntering = False)
	
	If Company.LegalEntityIndividual = PredefinedValue("Enum.LegalEntityIndividual.Ind") Then
		IndividualObject = FormAttributeToValue("Individual");
		IndividualObject.Write();
		Company.Individual = IndividualObject.Ref;
	EndIf;
	CompanyObject = FormAttributeToValue("Company");
	CompanyObject.Write();
	
	RecordSet = InformationRegisters.ResponsiblePersons.CreateRecordSet();
	DateBegOfYear = BegOfYear(CurrentDate());
	
	If ValueIsFilled(Chiefexecutive.Description) Then
		ChiefExecutiveObject = FormAttributeToValue("Chiefexecutive");
		ChiefExecutiveObject.OccupationType = ?(ValueIsFilled(ChiefExecutiveObject.OccupationType), ChiefExecutiveObject.OccupationType, Enums.OccupationTypes.MainWorkplace);
		ChiefExecutiveObject.Write();
		PositionObject = Catalogs.Positions.FindByDescription("Chiefexecutive");
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = "Chiefexecutive";
			PositionObject.Write();
		EndIf;
		NewRow = RecordSet.Add();
		NewRow.Company = CompanyObject.Ref;
		NewRow.ResponsiblePersonType = Enums.ResponsiblePersonTypes.Head;
		NewRow.Employee = ChiefExecutiveObject.Ref;
		NewRow.Period = DateBegOfYear;
		NewRow.Position = PositionObject.Ref;
	EndIf;
	
	If ValueIsFilled(ChiefAccountant.Description) Then
		If ChiefAccountant.Description = Chiefexecutive.Description
		 OR ChiefAccountant.Ref = Chiefexecutive.Ref Then
			ChiefAccountantObject = ChiefExecutiveObject;
		Else
			ChiefAccountantObject = FormAttributeToValue("ChiefAccountant");
			ChiefAccountantObject.OccupationType = ?(ValueIsFilled(ChiefAccountantObject.OccupationType), ChiefAccountantObject.OccupationType, Enums.OccupationTypes.MainWorkplace);
			ChiefAccountantObject.Write();
		EndIf;
		PositionObject = Catalogs.Positions.FindByDescription("Chief accountant");
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = "Chief accountant";
			PositionObject.Write();
		EndIf;
		NewRow = RecordSet.Add();
		NewRow.Company = CompanyObject.Ref;
		NewRow.ResponsiblePersonType = Enums.ResponsiblePersonTypes.ChiefAccountant;
		NewRow.Employee = ChiefAccountantObject.Ref;
		NewRow.Period = DateBegOfYear;
		NewRow.Position = PositionObject.Ref;
	EndIf;
	
	If ValueIsFilled(Cashier.Description) Then
		If Cashier.Description = Chiefexecutive.Description
		 OR Cashier.Ref = Chiefexecutive.Ref Then
			CashierObject = ChiefExecutiveObject;
		ElsIf Cashier.Description = ChiefAccountant.Description
		 OR Cashier.Ref = ChiefAccountant.Ref Then
			CashierObject = ChiefAccountantObject;
		Else
			CashierObject = FormAttributeToValue("Cashier");
			CashierObject.OccupationType = ?(ValueIsFilled(CashierObject.OccupationType), CashierObject.OccupationType, Enums.OccupationTypes.MainWorkplace);
			CashierObject.Write();
		EndIf;
		PositionObject = Catalogs.Positions.FindByDescription("Cashier");
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = "Cashier";
			PositionObject.Write();
		EndIf;
		NewRow = RecordSet.Add();
		NewRow.Company = CompanyObject.Ref;
		NewRow.ResponsiblePersonType = Enums.ResponsiblePersonTypes.Cashier;
		NewRow.Employee = CashierObject.Ref;
		NewRow.Period = DateBegOfYear;
		NewRow.Position = PositionObject.Ref;
	EndIf;
	
	If ValueIsFilled(WarehouseMan.Description) Then
		If WarehouseMan.Description = Chiefexecutive.Description
		 OR WarehouseMan.Ref = Chiefexecutive.Ref Then
			WarehouseManObject = ChiefExecutiveObject;
		ElsIf WarehouseMan.Description = ChiefAccountant.Description
		 OR WarehouseMan.Ref = ChiefAccountant.Ref Then
			WarehouseManObject = ChiefAccountantObject;
		ElsIf WarehouseMan.Description = Cashier.Description
		 OR WarehouseMan.Ref = Cashier.Ref Then
			WarehouseManObject = CashierObject;
		Else
			WarehouseManObject = FormAttributeToValue("WarehouseMan");
			WarehouseManObject.OccupationType = ?(ValueIsFilled(WarehouseManObject.OccupationType), WarehouseManObject.OccupationType, Enums.OccupationTypes.MainWorkplace);
			WarehouseManObject.Write();
		EndIf;
		PositionObject = Catalogs.Positions.FindByDescription("WarehouseMan");
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = "WarehouseMan";
			PositionObject.Write();
		EndIf;
		NewRow = RecordSet.Add();
		NewRow.Company = CompanyObject.Ref;
		NewRow.ResponsiblePersonType = Enums.ResponsiblePersonTypes.WarehouseMan;
		NewRow.Employee = WarehouseManObject.Ref;
		NewRow.Period = DateBegOfYear;
		NewRow.Period = DateBegOfYear;
		NewRow.Position = PositionObject.Ref;
	EndIf;
	
	RecordSet.Write(True);
	
	If FinishEntering Then
		Constants.InitialSettingCompanyDetailsFilled.Set(True);
	EndIf;
	
EndProcedure // WriteFormChanges()

// Procedure sets the active page.
//
&AtClient
Procedure SetActivePage()
	
	StringLegalEntityIndividual = ?(Company.LegalEntityIndividual = PredefinedValue("Enum.LegalEntityIndividual.Ind"), "Individual", "LegalEntity");
	SearchString = "Step" + String(mCurrentPageNumber) + ?(mCurrentPageNumber = 2, StringLegalEntityIndividual, "");
	Items.Pages.CurrentPage = Items.Find(SearchString);
	
	ThisForm.Title = "Company information filling wizard (Step " + String(mCurrentPageNumber)+ "/" + String(mLastPage) + ")";
	
EndProcedure // SetActivePage()

// Procedure sets the buttons accessibility.
//
&AtClient
Procedure SetButtonsEnabled()
	
	Items.Back.Enabled = mCurrentPageNumber <> mFirstPage;
	
	If Not ValueIsFilled(Company.LegalEntityIndividual) Then
		Items.GoToNext.Enabled = False;
	EndIf;
	
	If mCurrentPageNumber = mLastPage Then
		Items.DecorationNextActionExplanation.Title = "To complete, click Finish";
		Items.GoToNext.Title = "Finish";
		Items.GoToNext.Representation = ButtonRepresentation.Text;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,True);
	Else
		Items.DecorationNextActionExplanation.Title = "Click ""Next"" to go to the next step";
		Items.GoToNext.Title = "Next";
		Items.GoToNext.Representation = ButtonRepresentation.PictureAndText;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,False);
	EndIf;
	
EndProcedure // SetButtonsEnabled()

// Procedure checks filling of the mandatory attributes when you go to the next page.
//
&AtClient
Procedure ExecuteActionsOnTransitionToNextPage(Cancel)
	
	ClearMessages();
	
	If mCurrentPageNumber = 2 Then
		
		If Not ValueIsFilled(Company.Description) Then
			MessageText = NStr("en = 'Specify short description'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"Description",
				"Company",
				Cancel
			);
		EndIf;
		If Company.LegalEntityIndividual = PredefinedValue("Enum.LegalEntityIndividual.Ind")
		AND Not ValueIsFilled(Individual.Description) Then
			MessageText = NStr("en = 'Specify the full name.'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"Description",
				"Ind",
				Cancel
			);
		EndIf;
		
	EndIf;
	
EndProcedure // ExecuteActionsOnTransitionToNextPage()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	mCurrentPageNumber = 1;
	mFirstPage = 1;
	mLastPage = 5;
	mFormRecordCompleted = False;
	
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // OnOpen()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	CompanyRef = Catalogs.Companies.MainCompany;
	ValueToFormAttribute(CompanyRef.GetObject(), "Company");
	
	If ValueIsFilled(CompanyRef.Individual) Then
		ValueToFormAttribute(CompanyRef.Individual.GetObject(), "Individual");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ResponsiblePersonsSliceLast.Employee,
	|	ResponsiblePersonsSliceLast.ResponsiblePersonType,
	|	ResponsiblePersonsSliceLast.Company
	|FROM
	|	InformationRegister.ResponsiblePersons.SliceLast AS ResponsiblePersonsSliceLast
	|WHERE
	|	ResponsiblePersonsSliceLast.Company = &Company";
	Query.SetParameter("Company", CompanyRef);
	
	SelectionQueryResult = Query.Execute().Select();
	
	While SelectionQueryResult.Next() Do
		
		If SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.Head Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "Chiefexecutive");
		ElsIf SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.ChiefAccountant Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "ChiefAccountant");
		ElsIf SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.Cashier Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "Cashier");
		ElsIf SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.WarehouseMan Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "WarehouseMan");
		EndIf;
		
	EndDo;
	
	If Company.Description = "LLC ""Our company""" Then
		Company.Description = "";
	EndIf;
	
	If Not ValueIsFilled(ChiefAccountant.OverrunGLAccount) Then
		ChiefAccountant.OverrunGLAccount = ChartsOfAccounts.Managerial.OverrunOfAdvanceHolders;
	EndIf;
	If Not ValueIsFilled(ChiefAccountant.SettlementsHumanResourcesGLAccount) Then
		ChiefAccountant.SettlementsHumanResourcesGLAccount = ChartsOfAccounts.Managerial.PayrollPaymentsOnPay;
	EndIf;
	If Not ValueIsFilled(ChiefAccountant.AdvanceHoldersGLAccount) Then
		ChiefAccountant.AdvanceHoldersGLAccount = ChartsOfAccounts.Managerial.AdvanceHolderPayments;
	EndIf;
	
	If Not ValueIsFilled(Chiefexecutive.OverrunGLAccount) Then
		Chiefexecutive.OverrunGLAccount = ChartsOfAccounts.Managerial.OverrunOfAdvanceHolders;
	EndIf;
	If Not ValueIsFilled(Chiefexecutive.SettlementsHumanResourcesGLAccount) Then
		Chiefexecutive.SettlementsHumanResourcesGLAccount = ChartsOfAccounts.Managerial.PayrollPaymentsOnPay;
	EndIf;
	If Not ValueIsFilled(Chiefexecutive.AdvanceHoldersGLAccount) Then
		Chiefexecutive.AdvanceHoldersGLAccount = ChartsOfAccounts.Managerial.AdvanceHolderPayments;
	EndIf;
	
	If Not ValueIsFilled(Cashier.OverrunGLAccount) Then
		Cashier.OverrunGLAccount = ChartsOfAccounts.Managerial.OverrunOfAdvanceHolders;
	EndIf;
	If Not ValueIsFilled(Cashier.SettlementsHumanResourcesGLAccount) Then
		Cashier.SettlementsHumanResourcesGLAccount = ChartsOfAccounts.Managerial.PayrollPaymentsOnPay;
	EndIf;
	If Not ValueIsFilled(Cashier.AdvanceHoldersGLAccount) Then
		Cashier.AdvanceHoldersGLAccount = ChartsOfAccounts.Managerial.AdvanceHolderPayments;
	EndIf;
	
	If Not ValueIsFilled(WarehouseMan.OverrunGLAccount) Then
		WarehouseMan.OverrunGLAccount = ChartsOfAccounts.Managerial.OverrunOfAdvanceHolders;
	EndIf;
	If Not ValueIsFilled(WarehouseMan.SettlementsHumanResourcesGLAccount) Then
		WarehouseMan.SettlementsHumanResourcesGLAccount = ChartsOfAccounts.Managerial.PayrollPaymentsOnPay;
	EndIf;
	If Not ValueIsFilled(WarehouseMan.AdvanceHoldersGLAccount) Then
		WarehouseMan.AdvanceHoldersGLAccount = ChartsOfAccounts.Managerial.AdvanceHolderPayments;
	EndIf;
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not mFormRecordCompleted
		AND Modified Then
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		ShowQueryBox(NOTifyDescription, NStr("en = 'Save changes?'"), QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure // BeforeClose()

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Cancel = False;
		ExecuteActionsOnTransitionToNextPage(Cancel);
		If Not Cancel Then
			WriteFormChanges();
		EndIf;
		Modified = False;
		Close();
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - CloseForm command handler.
//
&AtClient
Procedure CloseForm(Command)
	
	Close(False);
	
EndProcedure // CloseForm()

// Procedure - CompleteFilling command handler.
//
&AtClient
Procedure CompleteFilling(Command)
	
	WriteFormChanges();
	Close(True);
	
EndProcedure // CompleteFilling()

// Procedure - Next command handler.
//
&AtClient
Procedure GoToNext(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	If mCurrentPageNumber = mLastPage Then
		WriteFormChanges(True);
		mFormRecordCompleted = True;
		Close(True);
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber + 1 > mLastPage, mLastPage, mCurrentPageNumber + 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // GoToNext()

// Procedure - Back command handler.
//
&AtClient
Procedure Back(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber - 1 < mFirstPage, mFirstPage, mCurrentPageNumber - 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Back()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration32Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 1;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration32Click()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration34Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 2;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration34Click()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration36Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 3;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration36Click()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration38Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 4;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration38Click()

// Procedure - event handler OnChange of the CompanyDescription attribute.
//
&AtClient
Procedure CompanyDescriptionOnChange(Item)
	
	If IsBlankString(Company.DescriptionFull)
	   AND IsBlankString(Company.PayerDescriptionOnTaxTransfer) Then
		
		If Company.LegalEntityIndividual = PredefinedValue("Enum.LegalEntityIndividual.Ind") Then
			Company.DescriptionFull = "CO """+Company.Description+"""";
		Else
			Company.DescriptionFull = "LLC """+Company.Description+"""";
		EndIf;
		Company.PayerDescriptionOnTaxTransfer = Company.DescriptionFull;
		
	EndIf;
	
EndProcedure // CompanyDescriptionOnChange()

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

&AtClient
Procedure ChiefExecutiveNameOnChange(Item)
	
	If Not ValueIsFilled(Chiefexecutive.Ref) Then
		Return;
	EndIf;
	
	If Chiefexecutive.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = Chiefexecutive.Description;
	EndIf;
	
	If Chiefexecutive.Ref = Cashier.Ref Then
		Cashier.Description = Chiefexecutive.Description;
	EndIf;
	
	If Chiefexecutive.Ref = WarehouseMan.Ref Then
		WarehouseMan.Description = Chiefexecutive.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChiefAccountantNameOnChange(Item)
	
	If Not ValueIsFilled(ChiefAccountant.Ref) Then
		Return;
	EndIf;
	
	If ChiefAccountant.Ref = Chiefexecutive.Ref Then
		Chiefexecutive.Description = ChiefAccountant.Description;
	EndIf;
	
	If ChiefAccountant.Ref = Cashier.Ref Then
		Cashier.Description = ChiefAccountant.Description;
	EndIf;
	
	If ChiefAccountant.Ref = WarehouseMan.Ref Then
		WarehouseMan.Description = ChiefAccountant.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure CashierDescriptionOnChange(Item)
	
	If Not ValueIsFilled(Cashier.Ref) Then
		Return;
	EndIf;
	
	If Cashier.Ref = Chiefexecutive.Ref Then
		Chiefexecutive.Description = Cashier.Description;
	EndIf;
	
	If Cashier.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = Cashier.Description;
	EndIf;
	
	If Cashier.Ref = WarehouseMan.Ref Then
		WarehouseMan.Description = Cashier.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure WarehouseManNameOnChange(Item)
	
	If Not ValueIsFilled(WarehouseMan.Ref) Then
		Return;
	EndIf;
	
	If WarehouseMan.Ref = Chiefexecutive.Ref Then
		Chiefexecutive.Description = WarehouseMan.Description;
	EndIf;
	
	If WarehouseMan.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = WarehouseMan.Description;
	EndIf;
	
	If WarehouseMan.Ref = Cashier.Ref Then
		Cashier.Description = WarehouseMan.Description;
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
