
// Storing context of interaction with the service
&AtClient
Var RegistrationContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ReadOnly = Parameters.ReadOnly;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CountryBeforeChange = Country;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CountryOnChange(Item)
	
	If CountryBeforeChange = Country Then
		Return;
	EndIf;
	
	CountryStates = RegistrationContext.CountryStates[Country];
	If CountryStates = Undefined Then
		CountryStates = New ValueList;
		CountryStates.Add("-1", NStr("en='<Not selected>';ru='<не выбран>'"));
	EndIf;
	
	OnlineUserSupportClient.CopyValueListIteratively(
		CountryStates,
		Items.StateCode.ChoiceList);
	
	StateCode = "-1";
	
	CountryBeforeChange = Country;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	
	If ReadOnly Then
		Close();
	Else
		Close(AddressDataStructure());
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function AddressDataStructure()
	
	Result = New Structure;
	Result.Insert("Country"    , Country);
	Result.Insert("IndexOf"    , IndexOf);
	Result.Insert("StateCode", StateCode);
	Result.Insert("Region"     , Region);
	Result.Insert("City"     , City);
	Result.Insert("Street"     , Street);
	Result.Insert("Building"       , Building);
	Result.Insert("Construction"  , Construction);
	Result.Insert("Apartment"  , Apartment);
	
	Return Result;
	
EndFunction

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
