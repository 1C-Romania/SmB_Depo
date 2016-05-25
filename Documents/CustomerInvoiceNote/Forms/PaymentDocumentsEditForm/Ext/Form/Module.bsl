
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AddressPaymentDocumentsInStorage = Parameters.AddressPaymentDocumentsInStorage;
	PaymentDocumentsDateNumber.Load(GetFromTempStorage(AddressPaymentDocumentsInStorage));
	
EndProcedure

&AtServer
Procedure WritePaymentDocumentsToStorage()
	
	PaymentDocumentsInStorage = PaymentDocumentsDateNumber.Unload();
	PutToTempStorage(PaymentDocumentsInStorage, AddressPaymentDocumentsInStorage);
	
EndProcedure // WritePaymentDocumentsToStorage()


&AtClient
Procedure OK(Command)
	
	WritePaymentDocumentsToStorage();
	Close(DialogReturnCode.OK);
	
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
