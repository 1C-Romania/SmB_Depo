
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
// The procedure updates the page title.
//
Procedure UpdateRegisterPageTitle(AttributeOfHeader, ListOfRegisters)

	AttributeOfHeader = String(GetQuantityOfMarked(ListOfRegisters)) + "/" + String(ListOfRegisters.Count());

EndProcedure // UpdateRegisterPageTitle()

&AtClient
// The procedure creates the registers list for a manual correction.
//
Procedure CreateRegistersListForCorrection(ResultList, ListOfRegisters)

	For Each Item IN ListOfRegisters Do

		RegisterIsUsed = ListOfUsedRegisters.FindByValue(Item.Value) <> Undefined;
		// It is required to disable the register.
		If Item.Check AND Not RegisterIsUsed Then

			ResultList.Add(Item.Value, Item.Presentation, True);

		// It is required to add the register.
		ElsIf Not Item.Check AND RegisterIsUsed Then

			ResultList.Add(Item.Value, Item.Presentation, False);

		EndIf;
	EndDo;

EndProcedure // CreateRegistersListForCorrection()

&AtClientAtServerNoContext
// The function returns the quantity of the marked registers in the list.
//
Function GetQuantityOfMarked(ValueList)

	Result = 0;
	For Each Item IN ValueList Do
		If Item.Check Then
			Result = Result + 1;
		EndIf;
	EndDo;

	Return Result;

EndFunction // GetQuantityOfMarked()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	ListOfUsedRegisters.LoadValues(Parameters.ListOfUsedRegisters.UnloadValues());
	For Each Register IN Metadata.Documents.RegistersCorrection.RegisterRecords Do

		If Metadata.AccumulationRegisters.Contains(Register) Then

			Check = ListOfUsedRegisters.FindByValue(Register.Name) <> Undefined;
			ListOfAccumulationRegisters.Add(Register.Name, Register.Synonym, Check);

		EndIf;

	EndDo;

	ListOfAccumulationRegisters.SortByValue(SortDirection.Asc);

	For Each Register IN Metadata.Documents.RegistersCorrection.RegisterRecords Do

		If Metadata.InformationRegisters.Contains(Register) Then

			Check = ListOfUsedRegisters.FindByValue(Register.Name) <> Undefined;
			ListOfInformationRegisters.Add(Register.Name, Register.Synonym, Check);

		EndIf;

	EndDo;

	ListOfInformationRegisters.SortByValue(SortDirection.Asc);

EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - event handler OnOpen.
//
Procedure OnOpen(Cancel)

	UpdateRegisterPageTitle(TitlePagesAccumulationRegisters, ListOfAccumulationRegisters);

	UpdateRegisterPageTitle(TitlePagesInformationRegisters, ListOfInformationRegisters);

EndProcedure // OnOpen()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// The procedure is called after clicking the "OK" button in the form command bar.
//
Procedure OK(Command)
	
	Result = New ValueList;

	CreateRegistersListForCorrection(Result, ListOfAccumulationRegisters);
	CreateRegistersListForCorrection(Result, ListOfInformationRegisters);

	Close(Result);
	
EndProcedure // Ok()

////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
// Procedure - OnChange event handler of the AccumulationRegistersList list.
//
Procedure AccumulationRegisterListOnChange(Item)
	
	UpdateRegisterPageTitle(TitlePagesAccumulationRegisters, ListOfAccumulationRegisters);
	
EndProcedure // AccumulationRegisterListOnChange()

&AtClient
// Procedure - OnChange event handler of the InformationRegistersList list.
//
Procedure InformationRegisterListOnChange(Item)
	
	UpdateRegisterPageTitle(TitlePagesInformationRegisters, ListOfInformationRegisters);
	
EndProcedure // InformationRegisterListOnChange()



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
