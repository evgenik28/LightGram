#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

typedef void (^LGPlatformAddressBookAccessCompletion)(bool granted, CFErrorRef error);

FOUNDATION_EXPORT ABAddressBookRef LGPlatformAddressBookCreate(CFErrorRef *error);
FOUNDATION_EXPORT void LGPlatformAddressBookRequestAccess(ABAddressBookRef addressBook, LGPlatformAddressBookAccessCompletion completion);
