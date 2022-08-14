package project

import (
	"fmt"
)

func myProject(myString string) string {
	newString := "hello " + myString
	fmt.Println(newString)

	return newString
}
