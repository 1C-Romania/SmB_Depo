
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



