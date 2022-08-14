package project

import (
	"testing"
)

func TestMyProject(t *testing.T) {
	outString := myProject("username")
	expectedValue := "hello username"

	if outString != expectedValue {
		t.Errorf("myProject does not match, got: %s want: %s", outString, expectedValue)
	}
}
